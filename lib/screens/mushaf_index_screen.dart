import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quran_repository.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';

/// The mushaf's table of contents. Two tabs — surahs grouped under the juz
/// they start in, and juz broken down into their two ahzab — plus a search
/// that spans both surah names and the ayah text itself.
///
/// Pops with the [AyahRef] the reader picked, or null if they backed out.
class MushafIndexScreen extends StatefulWidget {
  final int currentSurah;
  const MushafIndexScreen({super.key, required this.currentSurah});

  @override
  State<MushafIndexScreen> createState() => _MushafIndexScreenState();
}

class _MushafIndexScreenState extends State<MushafIndexScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(AyahRef ref) => Navigator.of(context).pop(ref);

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    final searching = _query.trim().length >= 2;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(strings.index, style: uiFont(size: 20, weight: FontWeight.w600, color: AppColors.ink)),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(searching ? 66 : 114),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    style: uiFont(size: 16, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: strings.searchHint,
                      hintStyle: uiFont(size: 16, color: AppColors.ink3),
                      prefixIcon: Icon(Icons.search_rounded, size: 22, color: AppColors.ink3),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.paper,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (!searching)
                  TabBar(
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.ink3,
                    indicatorColor: AppColors.gold,
                    indicatorWeight: 3,
                    labelStyle: uiFont(size: 17, weight: FontWeight.w600),
                    unselectedLabelStyle: uiFont(size: 17, weight: FontWeight.w500),
                    tabs: [Tab(text: strings.surahs), Tab(text: strings.juzTab)],
                  ),
              ],
            ),
          ),
        ),
        body: searching
            ? _results(_query.trim())
            : const TabBarView(children: [_SurahsByJuz(), _JuzWithHizbs()]),
      ),
    );
  }

  Widget _results(String query) {
    final strings = context.watch<SettingsState>().strings;
    final surahs = QuranRepo.searchSurahs(query);
    final ayat = QuranRepo.searchAyat(query);

    if (surahs.isEmpty && ayat.isEmpty) {
      return Center(
        child: Text(strings.noResults, style: uiFont(size: 17, color: AppColors.ink3)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (surahs.isNotEmpty) ...[
          _groupHeader('${strings.surahs} (${ar(surahs.length)})'),
          for (final s in surahs)
            ListTile(
              onTap: () => _pick(AyahRef(s.number, 1)),
              leading: _numberBadge(s.number),
              title: Text(s.name, style: quranFont(size: 21, color: AppColors.ink)),
              trailing: Text('${ar(s.ayahCount)} ${strings.ayah}', style: uiFont(size: 14, color: AppColors.ink3)),
            ),
        ],
        if (ayat.isNotEmpty) ...[
          _groupHeader('${strings.ayat} (${ar(ayat.length)})'),
          for (final hit in ayat)
            ListTile(
              onTap: () => _pick(hit.ref),
              title: Text(hit.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: quranFont(size: 19, height: 1.9, color: AppColors.ink)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${hit.surahName} · ${strings.ayah} ${ar(hit.ref.ayah)}',
                    style: uiFont(size: 14, color: AppColors.ink3)),
              ),
            ),
        ],
      ],
    );
  }

  static Widget _groupHeader(String text) => Container(
        width: double.infinity,
        color: AppColors.paper,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Text(text, style: uiFont(size: 15, weight: FontWeight.w600, color: AppColors.ink2)),
      );

  static Widget _numberBadge(int n) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.gold.withOpacity(.12),
        ),
        child: Text(ar(n), style: uiFont(size: 15, weight: FontWeight.w600, color: AppColors.gold)),
      );
}

/// Tab 1 — every juz, with the surahs it contains listed beneath it.
class _SurahsByJuz extends StatelessWidget {
  const _SurahsByJuz();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: QuranRepo.juzCount,
      itemBuilder: (context, i) {
        final juz = i + 1;
        final surahs = QuranRepo.surahsInJuz(juz);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MushafIndexScreenState._groupHeader('${strings.juz} ${ar(juz)}'),
            for (final s in surahs)
              ListTile(
                onTap: () => Navigator.of(context)
                    .pop(AyahRef(s, QuranRepo.juzRangeInSurah(juz, s).first)),
                leading: _MushafIndexScreenState._numberBadge(s),
                title: Text(QuranRepo.surahName(s), style: quranFont(size: 21, color: AppColors.ink)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${strings.ayat} ${ar(QuranRepo.juzRangeInSurah(juz, s).first)}'
                    '–${ar(QuranRepo.juzRangeInSurah(juz, s).last)}',
                    style: uiFont(size: 14, color: AppColors.ink3),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Tab 2 — every juz broken into its two ahzab.
class _JuzWithHizbs extends StatelessWidget {
  const _JuzWithHizbs();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: QuranRepo.juzCount,
      itemBuilder: (context, i) {
        final juz = i + 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MushafIndexScreenState._groupHeader('${strings.juz} ${ar(juz)}'),
            for (final hizb in QuranRepo.hizbsOfJuz(juz))
              Builder(builder: (context) {
                final start = QuranRepo.hizbStart(hizb);
                return ListTile(
                  onTap: () => Navigator.of(context).pop(start),
                  leading: _MushafIndexScreenState._numberBadge(hizb),
                  title: Text('${strings.hizb} ${ar(hizb)}',
                      style: uiFont(size: 17, weight: FontWeight.w600, color: AppColors.ink)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${strings.startsAt} ${QuranRepo.surahName(start.surah)} · ${strings.ayah} ${ar(start.ayah)}',
                      style: uiFont(size: 14, color: AppColors.ink3),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
