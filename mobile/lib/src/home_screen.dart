import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import 'account_screen.dart';
import 'app_controller.dart';
import 'models.dart';
import 'premium_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  JapMode mode = JapMode.tap;
  AppController get controller => widget.controller;

  void increment(JapMode selectedMode) {
    controller.increment(selectedMode);
    if (controller.vibrate) HapticFeedback.selectionClick();
    if (controller.tapSound) SystemSound.play(SystemSoundType.click);
  }

  void openPremium() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PremiumScreen(controller: controller)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sankalp'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Premium',
            onPressed: openPremium,
            icon: Icon(controller.isPremium ? Icons.workspace_premium : Icons.lock_open),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountScreen(controller: controller)),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Text(
              'ॐ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 34, color: Theme.of(context).colorScheme.primary),
            ),
            Text(
              'Your daily Naam Jap tracker',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _setupCard(),
            _counterCard(),
            _sectionTitle('Progress in blocks of 100'),
            _progressBlocks(),
            _statsCard(),
            _sectionTitle('Last 30 days'),
            _historyCard(),
            if (controller.isPremium) ...[
              _sectionTitle('Premium progress'),
              _premiumStats(),
            ],
            _sectionTitle('Settings'),
            _settingsCard(),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _shareProgress,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share progress'),
                ),
                if (controller.signedIn)
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            try {
                              await controller.sync();
                            } catch (_) {}
                          },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync'),
                  ),
              ],
            ),
            if (controller.message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(controller.message!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Choose today's Sankalp", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mantra in mantras)
                    ChoiceChip(
                      label: Text(mantra.hindi),
                      selected: controller.mantraId == mantra.id,
                      onSelected: (_) => controller.selectMantra(mantra.id),
                    ),
                  ChoiceChip(
                    label: const Text('✏️ Custom'),
                    selected: controller.mantraId == 'custom',
                    onSelected: (_) => _customMantraDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Target', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final value in [...AppController.freeGoals, 2108])
                    ChoiceChip(
                      label: Text('${value == 2108 ? '🔒 ' : ''}$value'),
                      selected: controller.goal == value,
                      onSelected: (_) {
                        if (!controller.selectGoal(value)) openPremium();
                      },
                    ),
                  ActionChip(
                    avatar: Icon(controller.isPremium ? Icons.edit : Icons.lock, size: 16),
                    label: const Text('Custom'),
                    onPressed: controller.isPremium ? _customGoalDialog : openPremium,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.lock, size: 16),
                    label: const Text('1 Lakh Monthly'),
                    onPressed:
                        controller.isPremium ? () => controller.selectGoal(100000) : openPremium,
                  ),
                ],
              ),
              if (controller.goal == 100000 && controller.isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Today’s suggested target: ${_monthlyDailyTarget()} Naam',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _counterCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                controller.mantraText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 190,
                height: 190,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: controller.progress,
                    color: Theme.of(context).colorScheme.primary,
                    track: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.decimalPattern().format(controller.count),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'of ${NumberFormat.decimalPattern().format(controller.goal)} today',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                '🔱 ${controller.completedMalas} malas + ${controller.currentBead} beads',
              ),
              const SizedBox(height: 4),
              Text(
                controller.count >= controller.goal
                    ? '🪔 Sankalp complete'
                    : '${controller.goal - controller.count} Naam to complete today',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              SegmentedButton<JapMode>(
                segments: const [
                  ButtonSegment(value: JapMode.tap, label: Text('Tap')),
                  ButtonSegment(
                    value: JapMode.mala,
                    label: Text('Mala'),
                    icon: Icon(Icons.lock, size: 14),
                  ),
                  ButtonSegment(
                    value: JapMode.write,
                    label: Text('Write'),
                    icon: Icon(Icons.lock, size: 14),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  final next = selection.first;
                  if (next != JapMode.tap && !controller.isPremium) {
                    openPremium();
                    return;
                  }
                  setState(() => mode = next);
                },
              ),
              const SizedBox(height: 18),
              _modeContent(),
              const SizedBox(height: 12),
              _garden(),
            ],
          ),
        ),
      );

  Widget _modeContent() {
    return switch (mode) {
      JapMode.tap => SizedBox(
          width: double.infinity,
          height: 116,
          child: FilledButton(
            onPressed: () => increment(JapMode.tap),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(controller.mantraText, style: const TextStyle(fontSize: 23)),
                const Text('Tap to chant · +1'),
              ],
            ),
          ),
        ),
      JapMode.mala => _malaMode(),
      JapMode.write => _WritingPad(
          guide: controller.mantraText,
          onDone: () => increment(JapMode.write),
        ),
    };
  }

  Widget _malaMode() => Column(
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              children: [
                for (var index = 0; index < 108; index++)
                  Positioned(
                    left: 121 +
                        109 * math.cos((index / 108) * math.pi * 2 - math.pi / 2),
                    top: 121 +
                        109 * math.sin((index / 108) * math.pi * 2 - math.pi / 2),
                    child: Container(
                      width: index == controller.currentBead ? 10 : 7,
                      height: index == controller.currentBead ? 10 : 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < controller.currentBead
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                  ),
                Center(
                  child: SizedBox(
                    width: 112,
                    height: 112,
                    child: FilledButton(
                      onPressed: () => increment(JapMode.mala),
                      style: FilledButton.styleFrom(shape: const CircleBorder()),
                      child: const Text('तप करें'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Bead ${controller.currentBead} of 108 · Mala ${controller.completedMalas + 1}',
          ),
        ],
      );

  Widget _garden() {
    final stage = switch (controller.progress) {
      >= 1 => ('🪔', 'Complete — a lamp is lit'),
      >= .85 => ('🌳', 'Your Sankalp tree'),
      >= .65 => ('🌺', 'Blooming'),
      >= .45 => ('🌸', 'A flower appears'),
      >= .3 => ('🪴', 'A young plant'),
      >= .15 => ('🌿', 'A sprout appears'),
      _ => ('🌱', 'A seed is planted'),
    };
    return Column(
      children: [
        Text(stage.$1, style: const TextStyle(fontSize: 32)),
        Text(stage.$2, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _progressBlocks() {
    final blocks = math.max(1, (controller.goal / 100).ceil());
    final visible = math.min(blocks, 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < visible; index++)
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: controller.count >= math.min((index + 1) * 100, controller.goal)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  controller.count >= math.min((index + 1) * 100, controller.goal)
                      ? '🪔'
                      : '${index + 1}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            if (blocks > visible) Text('+${blocks - visible} more blocks'),
          ],
        ),
      ),
    );
  }

  Widget _statsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _stat('🔥', controller.streak, 'Day streak'),
              _stat('🏆', controller.bestStreak, 'Best streak'),
              _stat('🙏', controller.lifetime, 'Lifetime'),
            ],
          ),
        ),
      );

  Widget _stat(String icon, int value, String label) => Expanded(
        child: Column(
          children: [
            Text(icon),
            Text(
              NumberFormat.compact().format(value),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _historyCard() {
    final rows = {for (final row in controller.history) row.date: row};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 30,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final day = DateTime.now().subtract(Duration(days: 29 - index));
            final key = DateFormat('yyyy-MM-dd').format(day);
            final row = rows[key];
            final current = key == controller.date;
            final total = current ? controller.count : row?.total ?? 0;
            final goal = current ? controller.goal : row?.goal ?? controller.goal;
            final color = total >= goal && total > 0
                ? Theme.of(context).colorScheme.primary
                : total > 0
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.primaryContainer;
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
              child: Text('${day.day}', style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
    );
  }

  Widget _premiumStats() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _stat('👆', controller.tapCount, 'Tap'),
                  _stat('📿', controller.malaCount, 'Mala'),
                  _stat('✍️', controller.writeCount, 'Written'),
                ],
              ),
              const Divider(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('📊', style: TextStyle(fontSize: 28)),
                title: const Text('This month'),
                trailing: Text(
                  NumberFormat.decimalPattern().format(controller.monthlyCount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _settingsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration on tap'),
                value: controller.vibrate,
                onChanged: controller.setVibration,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tap sound'),
                subtitle: const Text('Play a soft click for each count'),
                value: controller.tapSound,
                onChanged: controller.setTapSound,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Theme'),
                trailing: DropdownButton<String>(
                  value: controller.theme,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setTheme(value);
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('🔔 Daily Sankalp reminder'),
                subtitle: controller.reminderEnabled
                    ? Text(
                        '${controller.reminderHour.toString().padLeft(2, '0')}:'
                        '${controller.reminderMinute.toString().padLeft(2, '0')}',
                      )
                    : null,
                value: controller.reminderEnabled,
                onChanged: (value) async {
                  if (value) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: controller.reminderHour,
                        minute: controller.reminderMinute,
                      ),
                    );
                    if (time != null) {
                      await controller.setReminder(
                        true,
                        hour: time.hour,
                        minute: time.minute,
                      );
                    }
                  } else {
                    await controller.setReminder(false);
                  }
                },
              ),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 5),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  int _monthlyDailyTarget() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = math.max(1, lastDay - now.day + 1);
    return math.max(0, ((100000 - controller.monthlyCount) / remainingDays).ceil());
  }

  Future<void> _shareProgress() async {
    await SharePlus.instance.share(
      ShareParams(
        text: '${controller.mantraText} 🙏\n'
            '${NumberFormat.decimalPattern().format(controller.count)} / '
            '${NumberFormat.decimalPattern().format(controller.goal)} Naam today\n'
            '🔥 ${controller.streak} day streak · '
            '📿 ${controller.completedMalas} malas\n'
            'Completed with श्रद्धा using Sankalp.',
      ),
    );
  }

  Future<void> _customMantraDialog() async {
    final text = TextEditingController(text: controller.customMantra);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom mantra'),
        content: TextField(controller: text, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('Use mantra'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value != null && value.isNotEmpty) {
      controller.selectMantra('custom', custom: value);
    }
  }

  Future<void> _customGoalDialog() async {
    final text = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom target'),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Example: 11111'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(text.text)),
            child: const Text('Set target'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value != null && value > 0) controller.selectGoal(value);
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    paint.color = track;
    canvas.drawArc(rect.deflate(10), -math.pi / 2, math.pi * 2, false, paint);
    paint.color = color;
    canvas.drawArc(
      rect.deflate(10),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _WritingPad extends StatefulWidget {
  const _WritingPad({required this.guide, required this.onDone});
  final String guide;
  final VoidCallback onDone;

  @override
  State<_WritingPad> createState() => _WritingPadState();
}

class _WritingPadState extends State<_WritingPad> {
  final points = <Offset?>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanStart: (event) => setState(() => points.add(event.localPosition)),
          onPanUpdate: (event) => setState(() => points.add(event.localPosition)),
          onPanEnd: (_) => setState(() => points.add(null)),
          child: Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: CustomPaint(
              painter: _WritingPainter(
                points: points,
                guide: widget.guide,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Write the Naam, then tap Done to count +1'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: () => setState(points.clear), child: const Text('Clear')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: points.whereType<Offset>().length < 3
                  ? null
                  : () {
                      widget.onDone();
                      setState(points.clear);
                    },
              icon: const Icon(Icons.check),
              label: const Text('Done · +1'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WritingPainter extends CustomPainter {
  const _WritingPainter({
    required this.points,
    required this.guide,
    required this.color,
  });

  final List<Offset?> points;
  final String guide;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePainter = TextPainter(
      text: TextSpan(
        text: guide,
        style: TextStyle(color: color.withValues(alpha: .18), fontSize: 30),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    guidePainter.paint(
      canvas,
      Offset(
        (size.width - guidePainter.width) / 2,
        (size.height - guidePainter.height) / 2,
      ),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < points.length - 1; index++) {
      final from = points[index];
      final to = points[index + 1];
      if (from != null && to != null) canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WritingPainter oldDelegate) => true;
}
