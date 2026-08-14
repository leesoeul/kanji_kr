/// 음독·훈독 한 줄. romaji는 시드에만 있고 UI에서는 잘 안 쓴다.
/// 音読み・訓読みの1行。romaji はシードにだけあり、UIではあまり使わない。
class Reading {
  const Reading({
    required this.kana,
    this.romaji = '',
  });

  final String kana;
  final String romaji;

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      kana: json['kana'] as String,
      romaji: json['romaji'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'kana': kana,
        'romaji': romaji,
      };

  String get display => romaji.isEmpty ? kana : '$kana ($romaji)';
}
