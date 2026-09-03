/// 음독·훈독 한 줄.
///
/// [kana]가 화면에 쓰는 값. [romaji]는 시드에만 있고 UI에서는 거의 안 쓴다.
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
