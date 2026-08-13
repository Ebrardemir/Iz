/// Günlük davet cümleleri — FR-032, FR-036.
///
/// Cümleler ÇEVİRİDE yaşıyor (arayüz metni), sıralaması burada. Hangisinin
/// gösterileceğine karar veren kural ise saf bir fonksiyonda
/// (`domain/journal_prompt.dart`) — üç parça birbirinden bağımsız değişebilsin
/// diye ayrı: yeni bir cümle eklemek bu listeye bir satır, kuralı değiştirmek
/// domain'de bir satır.
///
/// KİMLİK NEDEN İNDEKSTEN ÜRETİLİYOR?
/// `JournalEntry.promptId` hangi davete cevap verildiğini saklıyor (FR-032).
/// Kimliği metinden türetmek çeviri değişince bağı koparırdı; sıra numarası
/// dile bağlı değil. Cümlelerin SIRASI bu yüzden sabit — araya ekleme
/// yapılacaksa sona eklenmeli.
library;

import 'package:iz/core/l10n/generated/app_localizations.dart';

/// Havuzdaki cümleler — sırası kimliklerin kaynağı, değiştirme.
List<String> journalPrompts(AppL10n l10n) => [
  l10n.journalPrompt1,
  l10n.journalPrompt2,
  l10n.journalPrompt3,
  l10n.journalPrompt4,
  l10n.journalPrompt5,
];

/// [index] numaralı davetin kalıcı kimliği.
String journalPromptId(int index) => 'prompt-${index + 1}';
