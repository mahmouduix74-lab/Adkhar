/// App-wide feature switches.
///
/// The offline assistant (`lib/screens/chat_screen.dart`, `lib/data/assistant.dart`
/// and the corpus under `assets/corpus/`) is finished and covered by tests, but
/// it is held back from this release. Flipping this one flag back to `true`
/// restores its tab in the bottom bar and every route that opens it — nothing
/// about the feature is deleted, so it comes back exactly as it was.
const bool kAssistantEnabled = false;

/// Where "contact us" goes. Digits only, in full international form: Egypt's
/// country code (20) followed by the number without its leading zero.
const String kWhatsAppNumber = '201141578409';
