import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quran_repository.dart';
import '../data/quran_translation.dart';
import '../l10n/strings.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/arabic_numerals.dart';

/// Opened from the reader's selection bar: the selected ayat, their
/// tafsir, and a play button that recites them in order.
///
/// The Quran text is offline; the tafsir and the audio are not. Both fail
/// softly with their own message so a dropped connection never takes the
/// reader down with it.
class AyahSheet extends StatefulWidget {
  /// One or more selected ayat, in mushaf order.
  final List<AyahRef> refs;
  const AyahSheet({super.key, required this.refs});

  static Future<void> show(BuildContext context, List<AyahRef> refs) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => AyahSheet(refs: refs),
      );

  @override
  State<AyahSheet> createState() => _AyahSheetState();
}

class _AyahSheetState extends State<AyahSheet> {
  final _player = AudioPlayer();
  late Future<List<String>> _tafsir = _loadTafsir();
  Future<List<String>>? _translation;

  /// One tafsir per selected ayah, fetched together.
  Future<List<String>> _loadTafsir() =>
      Future.wait(widget.refs.map(QuranRepo.tafsir));

  Future<List<String>> _loadTranslation(int editionId) => Future.wait(
      widget.refs.map((r) => QuranRepo.translation(r, editionId)));

  int _playingIndex = 0;

  bool _playing = false;
  bool _loadingAudio = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_playing && _playingIndex + 1 < widget.refs.length) {
        _playFrom(_playingIndex + 1);
      } else {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() {
      _loadingAudio = true;
      _audioError = null;
      _playingIndex = 0;
    });
    await _playFrom(0);
  }

  /// Plays the selection one ayah after another; [onPlayerComplete] below
  /// advances to the next, so a multi-ayah selection recites straight
  /// through instead of stopping after the first.
  Future<void> _playFrom(int index) async {
    if (index >= widget.refs.length) {
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await _player.play(UrlSource(QuranRepo.audioUrl(widget.refs[index])));
      if (mounted) {
        setState(() {
          _playing = true;
          _playingIndex = index;
        });
      }
    } catch (_) {
      if (!mounted) return;
      final message = context.read<SettingsState>().strings.audioError;
      setState(() => _audioError = message);
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    final refs = widget.refs;
    final title = refs.length == 1
        ? '${QuranRepo.surahName(refs.first.surah)} · ${strings.ayah} ${ar(refs.first.ayah)}'
        : '${QuranRepo.surahName(refs.first.surah)} · '
            '${ar(refs.first.ayah)}–${ar(refs.last.ayah)} '
            '(${ar(refs.length)} ${strings.ayat})';

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: uiFont(size: 15, weight: FontWeight.w600, color: AppColors.gold)),
              const SizedBox(height: 14),
              Text(
                refs.map((r) => QuranRepo.verse(r.surah, r.ayah)).join(' ۝ '),
                textAlign: TextAlign.center,
                style: quranFont(size: 23, height: 2.1, color: AppColors.ink),
              ),
              const SizedBox(height: 18),
              Center(child: _audioButton()),
              if (_audioError != null) ...[
                const SizedBox(height: 8),
                Text(_audioError!,
                    textAlign: TextAlign.center,
                    style: uiFont(size: 14, color: AppColors.ink3)),
              ],
              const SizedBox(height: 22),
              Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 18),
              Text('التفسير الميسّر',
                  style: uiFont(size: 17, weight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 10),
              FutureBuilder<List<String>>(
                future: _tafsir,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                    );
                  }
                  if (snap.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تعذّر تحميل التفسير — يحتاج اتصالاً بالإنترنت.',
                            style: uiFont(size: 15, color: AppColors.ink3, height: 1.7)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _tafsir = _loadTafsir()),
                          child: Text('أعد المحاولة',
                              style: uiFont(size: 15, weight: FontWeight.w600, color: AppColors.gold)),
                        ),
                      ],
                    );
                  }
                  final texts = snap.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < texts.length; i++) ...[
                        if (texts.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('آية ${ar(refs[i].ayah)}',
                                style: uiFont(
                                    size: 14, weight: FontWeight.w600, color: AppColors.gold)),
                          ),
                        Text(texts[i],
                            style: uiFont(size: 16, color: AppColors.ink2, height: 1.9)),
                        if (i < texts.length - 1) const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
              ),
              _translationSection(strings),
            ],
          ),
        ),
      ),
    );
  }

  /// A translation of the *meanings*, shown only when the interface is in a
  /// language other than Arabic — for an Arabic reader the text above
  /// already is the Quran, and there is nothing to translate it into.
  ///
  /// The translator is named next to the heading, always. A translation of
  /// scripture with no name on it is an anonymous claim about what God
  /// said, and the reader is entitled to know whose understanding this is.
  Widget _translationSection(AppStrings strings) {
    final choice = QuranTranslation.forLanguage(strings.code);
    if (choice == null) return const SizedBox.shrink();

    _translation ??= _loadTranslation(choice.editionId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Divider(color: AppColors.line, height: 1),
        const SizedBox(height: 18),
        Text(strings.meaningsTranslation,
            style: uiFont(size: 17, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(choice.translator,
            style: uiFont(size: 13, color: AppColors.ink3)),
        const SizedBox(height: 10),
        FutureBuilder<List<String>>(
          future: _translation,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              );
            }
            if (snap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.translationFailed,
                      style: uiFont(size: 15, color: AppColors.ink3, height: 1.7)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(
                        () => _translation = _loadTranslation(choice.editionId)),
                    child: Text(strings.retry,
                        style: uiFont(
                            size: 15, weight: FontWeight.w600, color: AppColors.gold)),
                  ),
                ],
              );
            }
            final texts = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < texts.length; i++) ...[
                  if (texts.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${strings.ayah} ${ar(widget.refs[i].ayah)}',
                          style: uiFont(
                              size: 14, weight: FontWeight.w600, color: AppColors.gold)),
                    ),
                  Text(texts[i],
                      style: uiFont(size: 16, color: AppColors.ink2, height: 1.9)),
                  if (i < texts.length - 1) const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _audioButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _loadingAudio ? null : _toggleAudio,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: _loadingAudio
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              )
            : Icon(_playing ? Icons.stop_outlined : Icons.play_arrow_outlined,
                size: 24, color: AppColors.gold),
        label: Text(_playing
            ? 'إيقاف'
            : (widget.refs.length == 1 ? 'استمع للآية' : 'استمع للآيات'),
            style: uiFont(size: 16, weight: FontWeight.w600, color: AppColors.ink)),
      ),
    );
  }
}
