/// Anı detayındaki not: kapalıyken en çok iki satır, taşıyorsa açılır.
///
/// NEDEN "TAŞIYORSA"?
/// Not zorunlu değil ve uzunluğu tamamen kullanıcıya bağlı — bir cümle de
/// olabilir, üç paragraf da. Aç/kapa okunu her notta göstermek, iki satıra
/// sığan bir notta yanlış söz verirdi: kullanıcı oku görür, dokunur, hiçbir
/// şey açılmaz. O yüzden ok yalnızca gerçekten gizli metin varken çıkıyor.
///
/// "Gerçekten taşıyor mu" sorusunun cevabı ÖLÇÜMLE veriliyor
/// ([noteExceedsLines]), tahminle değil: karakter sayısına bakmak yanlış
/// olurdu — aynı 90 karakter bir telefonda iki, bir tablette tek satır.
library;

import 'package:flutter/material.dart';
import 'package:iz/core/extensions/context_x.dart';
import 'package:iz/core/theme/app_icons.dart';
import 'package:iz/core/theme/app_spacing.dart';

/// [text], [style] ile [maxWidth] genişliğinde [maxLines] satıra sığıyor mu?
///
/// SAF FONKSİYON: widget ağacına, temaya, `BuildContext`e ihtiyaç duymaz —
/// dolayısıyla doğrudan birim testiyle sınanabiliyor. Aynı hesabı widget'ın
/// içine gömseydik ancak ekran kurup piksel ölçerek test edebilirdik.
///
/// [textScaler] geçilmesi ŞART: erişilebilirlik ayarı açık bir kullanıcıda
/// aynı metin daha fazla satır kaplar ve ok o zaman görünmeli.
bool noteExceedsLines(
  String text, {
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textScaler: textScaler,
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);

  final exceeded = painter.didExceedMaxLines;
  // `TextPainter` yerel bir kaynak tutuyor; ölçtükten sonra bırakılmalı.
  painter.dispose();
  return exceeded;
}

class ExpandableNote extends StatefulWidget {
  const ExpandableNote({required this.note, super.key});

  final String note;

  /// Kapalı hâldeki satır sayısı.
  static const int kCollapsedLines = 2;

  /// Sağdaki ok için ayrılan yer (boşluk + ikon).
  ///
  /// ÖLÇÜMDE DE AYRILIYOR, sadece çizimde değil. Yoksa döngüye giriyorduk:
  /// ok görünecek mi diye metni ölçmek gerekiyor, ama metnin genişliği okun
  /// görünüp görünmemesine bağlı. Daralmış genişlikle ölçüp, sığıyorsa tam
  /// genişlikte çizmek bu döngüyü kırıyor — sığan metin daha geniş alanda da
  /// sığar.
  static const double kTrailingWidth = AppSpacing.sm + AppIconSize.md;

  @override
  State<ExpandableNote> createState() => _ExpandableNoteState();
}

class _ExpandableNoteState extends State<ExpandableNote> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final style =
        context.text.bodyMedium?.copyWith(color: colors.onSurface) ??
        const TextStyle();

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = noteExceedsLines(
          widget.note,
          style: style,
          maxWidth: constraints.maxWidth - ExpandableNote.kTrailingWidth,
          maxLines: ExpandableNote.kCollapsedLines,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        );

        final text = Text(
          widget.note,
          style: style,
          maxLines: _expanded ? null : ExpandableNote.kCollapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        );

        // Taşmıyorsa dokunulacak bir şey de yok: sade metin.
        if (!overflows) return text;

        return Semantics(
          button: true,
          label: _expanded ? l10n.memoryNoteCollapse : l10n.memoryNoteExpand,
          child: InkWell(
            // SATIRIN TAMAMI dokunulabilir, yalnızca ok değil — anı formunun
            // tarih satırıyla aynı desen. Ok bir düğme gibi değil, "devamı
            // var" işareti gibi duruyor ve dokunma hedefi metnin tamamı
            // oluyor (NFR-033).
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  _expanded ? AppIcons.collapse : AppIcons.expand,
                  size: AppIconSize.md,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
