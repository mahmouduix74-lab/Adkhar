import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/assistant.dart';
import '../state/settings_state.dart';
import '../theme.dart';

class _Turn {
  final bool fromUser;
  final String text;
  final List<AssistantAnswer> answers;
  const _Turn.user(this.text)
      : fromUser = true,
        answers = const [];
  const _Turn.bot(this.text, this.answers) : fromUser = false;
}

/// A retrieval assistant over the app's own sourced content.
///
/// It answers with the actual words of the mushaf or of Hisn al-Muslim and
/// always names where they came from. It does not compose answers, give
/// rulings, or guess — when it has nothing, it says so and points the
/// reader at a scholar. Anything more would mean putting unsourced
/// religious claims in front of someone acting on them.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _busy = false;

  Future<void> _send([String? preset]) async {
    final strings = context.read<SettingsState>().strings;
    final question = (preset ?? _input.text).trim();
    if (question.isEmpty || _busy) return;
    setState(() {
      _turns.add(_Turn.user(question));
      _input.clear();
      _busy = true;
    });
    _scrollToEnd();

    final answers = await Assistant.answer(question);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _turns.add(_Turn.bot(
        answers.isEmpty ? strings.assistantNone : strings.assistantFound,
        answers,
      ));
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(strings.assistant, style: pageTitle()),
          Text(strings.assistantSubtitle,
              style: uiFont(size: 13, color: AppColors.ink3)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty
                ? _empty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _turns.length + (_busy ? 1 : 0),
                    itemBuilder: (context, i) => i < _turns.length
                        ? _bubble(_turns[i])
                        : Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.gold),
                            ),
                          ),
                  ),
          ),
          _composer(strings.askPlaceholder),
        ],
      ),
    );
  }

  Widget _empty() {
    final strings = context.watch<SettingsState>().strings;
    const samples = ['دعاء دخول المنزل', 'معنى الصمد', 'إنما الأعمال بالنيات', 'دعاء الهم والحزن'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 20),
      children: [
        Icon(Icons.auto_awesome_outlined, size: 44, color: AppColors.gold),
        const SizedBox(height: 18),
        Text(strings.assistantTitle,
            textAlign: TextAlign.center,
            style: uiFont(size: 20, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 10),
        Text(
          strings.assistantBody,
          textAlign: TextAlign.center,
          style: uiFont(size: 15, color: AppColors.ink3, height: 1.9),
        ),
        const SizedBox(height: 26),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in samples)
              ActionChip(
                label: Text(s, style: uiFont(size: 14, color: AppColors.ink)),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.line),
                onPressed: () => _send(s),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bubble(_Turn turn) {
    if (turn.fromUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(turn.text, style: uiFont(size: 16, color: Colors.white, height: 1.6)),
        ),
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(turn.text,
                style: uiFont(size: 16, color: AppColors.ink, height: 1.7)),
          ),
          for (final a in turn.answers) _resultCard(a),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _resultCard(AssistantAnswer answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer.text,
              style: quranFont(size: 20, height: 2.0, color: AppColors.ink)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(
              answer.kind == AnswerKind.ayah
                  ? Icons.menu_book_outlined
                  : Icons.format_quote_outlined,
              size: 16,
              color: AppColors.gold,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(answer.citation,
                  style: uiFont(size: 13, weight: FontWeight.w600, color: AppColors.gold)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _composer(String hint) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                style: uiFont(size: 16, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: uiFont(size: 16, color: AppColors.ink3),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.gold,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  // "Send" travels the way the text does: left in Arabic,
                  // right in English.
                  child: Icon(forwardArrow, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
