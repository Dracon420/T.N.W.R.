/// Data model for T.N.W.R. Plain immutable classes with hand-written JSON so
/// the same shapes can be stored locally now and synced to Supabase later.
library;

enum RepeatKind { none, daily, weekly }

class Repeat {
  final RepeatKind kind;

  /// Weekdays for [RepeatKind.weekly], using DateTime.monday..DateTime.sunday.
  final List<int> weekdays;

  const Repeat({this.kind = RepeatKind.none, this.weekdays = const []});

  Map<String, dynamic> toJson() => {'kind': kind.name, 'weekdays': weekdays};

  factory Repeat.fromJson(Map<String, dynamic> j) => Repeat(
        kind: RepeatKind.values.byName(j['kind'] as String),
        weekdays: (j['weekdays'] as List? ?? const []).cast<int>(),
      );
}

/// Loudness tier shown in the sound picker. Levels are the files' average
/// loudness (printed by tools/gen_sounds.py); real volume depends on the
/// speaker and the system volume.
enum Loudness {
  soft('Soft', '≈ −20 dB'),
  loud('Loud', '≈ −4 dB'),
  louder('Louder', '≈ −1 to −2 dB'),
  loudest('Loudest', '≈ 0 dB, max');

  const Loudness(this.label, this.level);
  final String label;
  final String level;
}

enum AlarmSound {
  chime('chime_loop.wav', 'Gentle chime', 'High pitch, 1.3–1.8 kHz', Loudness.soft),
  beep('beep_loop.wav', 'Classic beep', 'High pitch, 1.3–1.8 kHz', Loudness.loud),
  siren('siren_loop.wav', 'Siren', 'Sweeps 0.7–1.6 kHz', Loudness.louder),
  lowTone('lowtone_loop.wav', 'Low tone 520 Hz',
      'Hard of hearing: the fire-alarm wake-up standard', Loudness.loud,
      forHardOfHearing: true),
  bass('bass_loop.wav', 'Bass pulse',
      'Hard of hearing: deep 200 Hz pulses', Loudness.louder,
      forHardOfHearing: true),
  blast('blast_loop.wav', 'Max blast',
      'Low 520–780 Hz square wave, no gaps', Loudness.loudest,
      forHardOfHearing: true);

  const AlarmSound(this.file, this.label, this.detail, this.loudness,
      {this.forHardOfHearing = false});

  final String file;
  final String label;
  final String detail;
  final Loudness loudness;

  /// Low-pitched sounds, which people with high-frequency hearing loss (the
  /// most common kind) hear much better than high beeps.
  final bool forHardOfHearing;
}

/// How the alarm gets worse the longer it's ignored.
class EscalationPolicy {
  /// System volume (0..1) when the alarm starts.
  final double startVolume;

  /// Volume added every [stepSeconds].
  final double stepSize;
  final int stepSeconds;
  final double maxVolume;

  /// Plays from the start, until [sirenAfterSeconds].
  final AlarmSound sound;

  /// Replaces [sound] once the alarm has been ignored [sirenAfterSeconds].
  final AlarmSound escalationSound;
  final int sirenAfterSeconds;

  /// Flash the alarm screen, for people who may not hear it at all.
  final bool flashScreen;

  /// Vibrate while ringing (phones).
  final bool vibrate;
  final int maxSnoozes;
  final int snoozeMinutes;

  const EscalationPolicy({
    this.startVolume = 0.3,
    this.stepSize = 0.1,
    this.stepSeconds = 20,
    this.maxVolume = 1.0,
    this.sound = AlarmSound.beep,
    this.escalationSound = AlarmSound.siren,
    this.sirenAfterSeconds = 120,
    this.flashScreen = false,
    this.vibrate = true,
    this.maxSnoozes = 1,
    this.snoozeMinutes = 5,
  });

  EscalationPolicy copyWith({
    double? startVolume,
    double? stepSize,
    int? stepSeconds,
    double? maxVolume,
    AlarmSound? sound,
    AlarmSound? escalationSound,
    int? sirenAfterSeconds,
    bool? flashScreen,
    bool? vibrate,
    int? maxSnoozes,
    int? snoozeMinutes,
  }) =>
      EscalationPolicy(
        startVolume: startVolume ?? this.startVolume,
        stepSize: stepSize ?? this.stepSize,
        stepSeconds: stepSeconds ?? this.stepSeconds,
        maxVolume: maxVolume ?? this.maxVolume,
        sound: sound ?? this.sound,
        escalationSound: escalationSound ?? this.escalationSound,
        sirenAfterSeconds: sirenAfterSeconds ?? this.sirenAfterSeconds,
        flashScreen: flashScreen ?? this.flashScreen,
        vibrate: vibrate ?? this.vibrate,
        maxSnoozes: maxSnoozes ?? this.maxSnoozes,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      );

  Map<String, dynamic> toJson() => {
        'startVolume': startVolume,
        'stepSize': stepSize,
        'stepSeconds': stepSeconds,
        'maxVolume': maxVolume,
        'sound': sound.name,
        'escalationSound': escalationSound.name,
        'sirenAfterSeconds': sirenAfterSeconds,
        'flashScreen': flashScreen,
        'vibrate': vibrate,
        'maxSnoozes': maxSnoozes,
        'snoozeMinutes': snoozeMinutes,
      };

  factory EscalationPolicy.fromJson(Map<String, dynamic> j) {
    // Unknown or missing names (older saves) fall back to the defaults.
    AlarmSound sound(String key, AlarmSound fallback) =>
        AlarmSound.values.asNameMap()[j[key]] ?? fallback;
    return EscalationPolicy(
      startVolume: (j['startVolume'] as num).toDouble(),
      stepSize: (j['stepSize'] as num).toDouble(),
      stepSeconds: j['stepSeconds'] as int,
      maxVolume: (j['maxVolume'] as num).toDouble(),
      sound: sound('sound', AlarmSound.beep),
      escalationSound: sound('escalationSound', AlarmSound.siren),
      sirenAfterSeconds: j['sirenAfterSeconds'] as int,
      flashScreen: j['flashScreen'] as bool? ?? false,
      vibrate: j['vibrate'] as bool? ?? true,
      maxSnoozes: j['maxSnoozes'] as int,
      snoozeMinutes: j['snoozeMinutes'] as int,
    );
  }
}

/// One way of proving a task is done. Each subtype carries its own settings.
sealed class ProofSpec {
  const ProofSpec();

  String get type;
  Map<String, dynamic> get _fields;

  Map<String, dynamic> toJson() => {'type': type, ..._fields};

  static ProofSpec fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'math' => MathProof(
            problems: j['problems'] as int, difficulty: j['difficulty'] as int),
        'typing' => TypingProof(words: j['words'] as int),
        'qr' => QrProof(code: j['code'] as String, label: j['label'] as String? ?? ''),
        'nfc' => NfcProof(tagId: j['tagId'] as String, label: j['label'] as String? ?? ''),
        'location' => LocationProof(
            lat: (j['lat'] as num).toDouble(),
            lng: (j['lng'] as num).toDouble(),
            radiusMeters: (j['radiusMeters'] as num).toDouble(),
            label: j['label'] as String),
        'steps' => StepsProof(steps: j['steps'] as int),
        'photo' => PhotoProof(
            referencePath: j['referencePath'] as String,
            referenceLabels:
                (j['referenceLabels'] as List? ?? const []).cast<String>(),
            threshold: (j['threshold'] as num).toDouble()),
        'approval' => ApprovalProof(
            approverName: j['approverName'] as String,
            approverPhone: j['approverPhone'] as String? ?? '',
            waitMinutes: j['waitMinutes'] as int? ?? 10),
        final t => throw FormatException('Unknown proof type: $t'),
      };
}

class MathProof extends ProofSpec {
  final int problems;

  /// 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;
  const MathProof({this.problems = 3, this.difficulty = 2});
  @override
  String get type => 'math';
  @override
  Map<String, dynamic> get _fields =>
      {'problems': problems, 'difficulty': difficulty};
}

class TypingProof extends ProofSpec {
  final int words;
  const TypingProof({this.words = 8});
  @override
  String get type => 'typing';
  @override
  Map<String, dynamic> get _fields => {'words': words};
}

/// Scan a specific barcode or QR code (anything printed: a medicine bottle,
/// a sticker by the washer...).
class QrProof extends ProofSpec {
  final String code;

  /// Where the code is, shown on the alarm ("the medicine bottle").
  final String label;
  const QrProof({required this.code, this.label = ''});
  @override
  String get type => 'qr';
  @override
  Map<String, dynamic> get _fields => {'code': code, 'label': label};
}

class NfcProof extends ProofSpec {
  final String tagId;
  final String label;
  const NfcProof({required this.tagId, this.label = ''});
  @override
  String get type => 'nfc';
  @override
  Map<String, dynamic> get _fields => {'tagId': tagId, 'label': label};
}

class LocationProof extends ProofSpec {
  final double lat, lng, radiusMeters;
  final String label;
  const LocationProof(
      {required this.lat,
      required this.lng,
      this.radiusMeters = 75,
      required this.label});
  @override
  String get type => 'location';
  @override
  Map<String, dynamic> get _fields =>
      {'lat': lat, 'lng': lng, 'radiusMeters': radiusMeters, 'label': label};
}

class StepsProof extends ProofSpec {
  final int steps;
  const StepsProof({this.steps = 200});
  @override
  String get type => 'steps';
  @override
  Map<String, dynamic> get _fields => {'steps': steps};
}

/// Photograph the finished task. Checked on the device: the new photo must
/// show enough of what the reference photo (taken at setup) showed.
class PhotoProof extends ProofSpec {
  final String referencePath;

  /// What on-device image labeling saw in the reference photo.
  final List<String> referenceLabels;

  /// Share (0..1) of the reference labels the new photo must also show.
  final double threshold;
  const PhotoProof(
      {required this.referencePath,
      this.referenceLabels = const [],
      this.threshold = 0.5});
  @override
  String get type => 'photo';
  @override
  Map<String, dynamic> get _fields => {
        'referencePath': referencePath,
        'referenceLabels': referenceLabels,
        'threshold': threshold,
      };
}

/// A person the user chooses (e.g. their spouse) approves a photo of the
/// finished task from a link texted to them. Needs the online backend.
class ApprovalProof extends ProofSpec {
  final String approverName;

  /// Where the link is texted; empty means "pick how to send it" each time.
  final String approverPhone;

  /// After the photo is sent, the alarm stays silent this long (1-20 min)
  /// waiting for the verdict, then rings again at the volume it had.
  final int waitMinutes;
  const ApprovalProof(
      {required this.approverName, this.approverPhone = '', this.waitMinutes = 10});
  @override
  String get type => 'approval';
  @override
  Map<String, dynamic> get _fields =>
      {'approverName': approverName, 'approverPhone': approverPhone, 'waitMinutes': waitMinutes};
}

/// Whether every proof is required, or any single one is enough.
enum ProofMode { all, any }

enum TaskStatus { scheduled, ringing, done }

class NagTask {
  final String id;
  final String title;
  final String notes;

  /// Next time this task rings.
  final DateTime dueAt;
  final Repeat repeat;
  final EscalationPolicy escalation;
  final List<ProofSpec> proofs;
  final ProofMode proofMode;
  final TaskStatus status;

  /// When the current ringing started; null unless [status] is ringing.
  final DateTime? ringingSince;
  final int snoozesUsed;

  /// Indexes into [proofs] already passed during the current ring. Saved so a
  /// passed proof isn't lost if Android closes the app (e.g. while the camera
  /// or messaging app is open).
  final List<int> passedProofs;

  /// A photo approval sent and awaiting a verdict during the current ring.
  final String? pendingApprovalId;
  final String? pendingApprovalUrl;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const NagTask({
    required this.id,
    required this.title,
    this.notes = '',
    required this.dueAt,
    this.repeat = const Repeat(),
    this.escalation = const EscalationPolicy(),
    this.proofs = const [MathProof()],
    this.proofMode = ProofMode.all,
    this.status = TaskStatus.scheduled,
    this.ringingSince,
    this.snoozesUsed = 0,
    this.passedProofs = const [],
    this.pendingApprovalId,
    this.pendingApprovalUrl,
    this.completedAt,
    required this.updatedAt,
  });

  NagTask copyWith({
    String? title,
    String? notes,
    DateTime? dueAt,
    Repeat? repeat,
    EscalationPolicy? escalation,
    List<ProofSpec>? proofs,
    ProofMode? proofMode,
    TaskStatus? status,
    DateTime? Function()? ringingSince,
    int? snoozesUsed,
    List<int>? passedProofs,
    String? Function()? pendingApprovalId,
    String? Function()? pendingApprovalUrl,
    DateTime? Function()? completedAt,
    DateTime? updatedAt,
  }) =>
      NagTask(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        dueAt: dueAt ?? this.dueAt,
        repeat: repeat ?? this.repeat,
        escalation: escalation ?? this.escalation,
        proofs: proofs ?? this.proofs,
        proofMode: proofMode ?? this.proofMode,
        status: status ?? this.status,
        ringingSince: ringingSince != null ? ringingSince() : this.ringingSince,
        snoozesUsed: snoozesUsed ?? this.snoozesUsed,
        passedProofs: passedProofs ?? this.passedProofs,
        pendingApprovalId: pendingApprovalId != null
            ? pendingApprovalId()
            : this.pendingApprovalId,
        pendingApprovalUrl: pendingApprovalUrl != null
            ? pendingApprovalUrl()
            : this.pendingApprovalUrl,
        completedAt: completedAt != null ? completedAt() : this.completedAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'dueAt': dueAt.toUtc().toIso8601String(),
        'repeat': repeat.toJson(),
        'escalation': escalation.toJson(),
        'proofs': [for (final p in proofs) p.toJson()],
        'proofMode': proofMode.name,
        'status': status.name,
        'ringingSince': ringingSince?.toUtc().toIso8601String(),
        'snoozesUsed': snoozesUsed,
        'passedProofs': passedProofs,
        'pendingApprovalId': pendingApprovalId,
        'pendingApprovalUrl': pendingApprovalUrl,
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory NagTask.fromJson(Map<String, dynamic> j) {
    DateTime? date(String key) =>
        j[key] == null ? null : DateTime.parse(j[key] as String).toLocal();
    return NagTask(
      id: j['id'] as String,
      title: j['title'] as String,
      notes: j['notes'] as String? ?? '',
      dueAt: date('dueAt')!,
      repeat: Repeat.fromJson(j['repeat'] as Map<String, dynamic>),
      escalation:
          EscalationPolicy.fromJson(j['escalation'] as Map<String, dynamic>),
      proofs: [
        for (final p in j['proofs'] as List)
          ProofSpec.fromJson(p as Map<String, dynamic>)
      ],
      proofMode: ProofMode.values.byName(j['proofMode'] as String),
      status: TaskStatus.values.byName(j['status'] as String),
      ringingSince: date('ringingSince'),
      snoozesUsed: j['snoozesUsed'] as int? ?? 0,
      passedProofs: (j['passedProofs'] as List? ?? const []).cast<int>(),
      pendingApprovalId: j['pendingApprovalId'] as String?,
      pendingApprovalUrl: j['pendingApprovalUrl'] as String?,
      completedAt: date('completedAt'),
      updatedAt: date('updatedAt')!,
    );
  }
}
