import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _pending = false;
  ApiProblem? _problem;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const _StatusScaffold(message: 'Checking your session…');
    }
    if (session.hasError) {
      return _StatusScaffold(
        message: "We couldn't reach Softxu. Check your connection and try again.",
        alert: true,
        action: 'Retry',
        onAction: () => ref.invalidate(sessionProvider),
      );
    }
    return _AuthScaffold(
      title: 'Sign in',
      subtitle: 'Use the email and password for your Softxu account.',
      pending: _pending,
      problem: _problem,
      submitLabel: 'Sign in',
      pendingLabel: 'Signing in…',
      footer: TextButton(
        onPressed: () => context.go('/register'),
        child: const Text('Create an account'),
      ),
      fields: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
      onSubmit: () async {
        setState(() {
          _pending = true;
          _problem = null;
        });
        final problem = await ref
            .read(sessionProvider.notifier)
            .login(email: _email.text.trim(), password: _password.text);
        if (mounted) {
          setState(() {
            _pending = false;
            _problem = problem;
          });
        }
      },
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _pending = false;
  ApiProblem? _problem;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const _StatusScaffold(message: 'Checking your session…');
    }
    return _AuthScaffold(
      title: 'Create an account',
      subtitle: 'The password is stored only as a hash.',
      pending: _pending,
      problem: _problem,
      submitLabel: 'Create account',
      pendingLabel: 'Creating account…',
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Sign in'),
      ),
      fields: [
        TextField(
          controller: _name,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
      onSubmit: () async {
        setState(() {
          _pending = true;
          _problem = null;
        });
        final problem = await ref
            .read(sessionProvider.notifier)
            .register(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _name.text.trim(),
            );
        if (mounted) {
          setState(() {
            _pending = false;
            _problem = problem;
          });
        }
      },
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.pending,
    required this.problem,
    required this.submitLabel,
    required this.pendingLabel,
    required this.onSubmit,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final bool pending;
  final ApiProblem? problem;
  final String submitLabel;
  final String pendingLabel;
  final VoidCallback onSubmit;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final message = problem == null
        ? null
        : problem!.isNetwork
        ? "We couldn't reach Softxu. Check your connection and try again."
        : [
            problem!.title,
            ...problem!.fieldErrors,
          ].where((line) => line.isNotEmpty).join(' ');
    return Scaffold(
      appBar: AppBar(title: const Text('Softxu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message, key: const Key('form-error')),
              ),
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field,
              ),
            ),
            FilledButton(
              onPressed: pending ? null : onSubmit,
              child: Text(pending ? pendingLabel : submitLabel),
            ),
            footer,
          ],
        ),
      ),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.message,
    this.alert = false,
    this.action,
    this.onAction,
  });

  final String message;
  final bool alert;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = alert ? Theme.of(context).colorScheme.error : null;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: color)),
              if (action != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
