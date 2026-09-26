enum JapMode { tap, mala, write }

class Mantra {
  const Mantra(this.id, this.hindi, this.english);

  final String id;
  final String hindi;
  final String english;
}

const mantras = <Mantra>[
  Mantra('jai_shri_ram', 'जय श्री राम', 'Jai Shri Ram'),
  Mantra('om_namah_shivay', 'ॐ नमः शिवाय', 'Om Namah Shivay'),
  Mantra('radhe_radhe', 'राधे राधे', 'Radhe Radhe'),
  Mantra('shri_krishna', 'श्री कृष्ण', 'Shri Krishna'),
  Mantra('hanuman', 'हनुमान', 'Hanuman'),
];

class DailyRecord {
  DailyRecord({
    required this.date,
    required this.goal,
    required this.total,
    required this.tap,
    required this.mala,
    required this.write,
  });

  final String date;
  final int goal;
  final int total;
  final int tap;
  final int mala;
  final int write;

  bool get complete => total >= goal;

  Map<String, dynamic> toJson() => {
        'date': date,
        'goal': goal,
        'total': total,
        'tap': tap,
        'mala': mala,
        'write': write,
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        date: json['date'] as String,
        goal: (json['goal'] as num?)?.toInt() ?? 108,
        total: (json['total'] as num?)?.toInt() ?? 0,
        tap: (json['tap'] as num?)?.toInt() ?? 0,
        mala: (json['mala'] as num?)?.toInt() ?? 0,
        write: (json['write'] as num?)?.toInt() ?? 0,
      );
}

