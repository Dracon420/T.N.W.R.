import 'package:flutter/material.dart';

import '../alarm/alarm_engine.dart';

/// Checklist of what Android must allow for alarms to ring with the app
/// closed. Re-checks whenever the user comes back from a settings page.
class PhoneSetupScreen extends StatelessWidget {
  const PhoneSetupScreen({super.key, required this.engine});

  final AndroidAlarmEngine engine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone setup')),
      body: _SetupStatus(
        engine: engine,
        builder: (context, missing) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              missing.isEmpty
                  ? 'All set. Alarms will ring even when T.N.W.R. is closed '
                      'or the phone is locked.'
                  : 'Allow these so alarms ring when T.N.W.R. is closed or the '
                      'phone is locked. Each button opens the right screen; '
                      'come back here afterwards.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            for (final item in SetupItem.values)
              Card(
                child: ListTile(
                  leading: Icon(
                    missing.contains(item)
                        ? Icons.error_outline
                        : Icons.check_circle,
                    color: missing.contains(item)
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.why),
                  trailing: missing.contains(item)
                      ? FilledButton(
                          onPressed: () => engine.fixSetup(item),
                          child: const Text('Fix'))
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner on the reminder list while setup is incomplete.
class PhoneSetupBanner extends StatelessWidget {
  const PhoneSetupBanner({super.key, required this.engine});

  final AndroidAlarmEngine engine;

  @override
  Widget build(BuildContext context) {
    return _SetupStatus(
      engine: engine,
      builder: (context, missing) => missing.isEmpty
          ? const SizedBox.shrink()
          : Card(
              margin: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Finish phone setup'),
                subtitle: Text(
                    '${missing.length} thing${missing.length == 1 ? '' : 's'} '
                    'to allow so alarms ring when T.N.W.R. is closed.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhoneSetupScreen(engine: engine))),
              ),
            ),
    );
  }
}

class _SetupStatus extends StatefulWidget {
  const _SetupStatus({required this.engine, required this.builder});

  final AndroidAlarmEngine engine;
  final Widget Function(BuildContext, Set<SetupItem> missing) builder;

  @override
  State<_SetupStatus> createState() => _SetupStatusState();
}

class _SetupStatusState extends State<_SetupStatus>
    with WidgetsBindingObserver {
  Set<SetupItem>? _missing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final missing = await widget.engine.missingSetup();
    if (mounted) setState(() => _missing = missing);
  }

  @override
  Widget build(BuildContext context) => _missing == null
      ? const SizedBox.shrink()
      : widget.builder(context, _missing!);
}
