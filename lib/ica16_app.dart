import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'attempt_repository.dart';
import 'firebase_options.dart';
import 'question.dart';

const kTriviaUrl =
    'https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple';
const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    FirebaseOptions options;
    if (useEmulators) {
      options = const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1234567890:android:ica16demo',
        messagingSenderId: '1234567890',
        projectId: 'demo-ica16-local',
      );
    } else {
      options = DefaultFirebaseOptions.currentPlatform;
    }
    await Firebase.initializeApp(options: options);
    if (useEmulators) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: kIsWeb ? '127.0.0.1' : '10.0.2.2',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    runApp(const Ica16App());
  } catch (error) {
    runApp(MaterialApp(home: SetupScreen(message: error.toString())));
  }
}

enum Fault {
  none,
  badJson,
  apiCode,
  nineResults,
  lostAck,
  unavailable,
  resourceExhausted,
  staleResponse,
}

extension FaultName on Fault {
  String get label {
    switch (this) {
      case Fault.none:
        return 'none';
      case Fault.badJson:
        return 'bad JSON';
      case Fault.apiCode:
        return 'api code 5';
      case Fault.nineResults:
        return 'nine results';
      case Fault.lostAck:
        return 'lost ack';
      case Fault.unavailable:
        return 'unavailable';
      case Fault.resourceExhausted:
        return 'quota';
      case Fault.staleResponse:
        return 'stale response';
    }
  }
}

enum Phase {
  loading,
  requestError,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  saveUnknown,
  notSaved,
  collision,
  permissionDenied,
  verificationUnavailable,
}

class Ica16App extends StatelessWidget {
  const Ica16App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICA16 Cloud Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22577A)),
      ),
      home: const AuthGate(),
    );
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ICA16 setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Firebase could not start.',
            style: TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 12),
          const Text(
            'Complete Firebase setup in the README, then rebuild the app.',
          ),
          const SizedBox(height: 12),
          SelectableText(message),
        ],
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _authChanges = FirebaseAuth.instance.authStateChanges();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) _password.clear();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = '${error.code}: ${error.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Busy(text: 'Checking sign-in…'));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Authentication unavailable: ${snapshot.error}'),
            ),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return QuizScreen(key: ValueKey(user.uid), user: user);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('ICA16 sign in')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(_busy ? 'Signing in…' : 'Sign in'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.user});
  final User user;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _repo = AttemptRepository(FirebaseFirestore.instance);
  Phase _phase = Phase.loading;
  Fault _fault = Fault.none;
  List<Question> _questions = [];
  final List<int> _selections = [];
  int _index = 0;
  int _score = 0;
  int? _picked;
  int _operation = 0;
  String _roundId = '';
  Map<String, dynamic>? _payload;
  String? _error;
  AttemptVerification? _verification;
  bool _lostAckFired = false;
  bool _fetching = false;
  bool _checkingSaved = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  bool get _busy =>
      _phase == Phase.loading ||
      _phase == Phase.submitting ||
      _phase == Phase.verifying ||
      _checkingSaved;

  bool get _unresolved =>
      _phase == Phase.submitting ||
      _phase == Phase.verifying ||
      _phase == Phase.saveUnknown ||
      _phase == Phase.verificationUnavailable;

  bool _current(int operation, String uid) {
    return mounted &&
        operation == _operation &&
        widget.user.uid == uid &&
        FirebaseAuth.instance.currentUser?.uid == uid;
  }

  Future<void> _startRound() async {
    if (_fetching || _unresolved || _checkingSaved) return;
    final uid = widget.user.uid;
    final operation = ++_operation;
    final fault = _fault;
    final roundId = _repo.newRoundId(uid);
    setState(() {
      _fetching = true;
      _phase = Phase.loading;
      _questions = [];
      _selections.clear();
      _index = 0;
      _score = 0;
      _picked = null;
      _payload = null;
      _error = null;
      _verification = null;
      _lostAckFired = false;
      _roundId = roundId;
    });
    try {
      final response = await http
          .get(Uri.parse(kTriviaUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw FormatException('HTTP ${response.statusCode}: expected 200.');
      }
      String body = response.body;
      if (fault == Fault.badJson) body = '{';
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        if (fault == Fault.apiCode) decoded['response_code'] = 5;
        if (fault == Fault.nineResults && decoded['results'] is List) {
          decoded['results'] = (decoded['results'] as List).take(9).toList();
        }
      }
      final loaded = parseRound(decoded);
      if (!_current(operation, uid)) return;
      setState(() {
        _fetching = false;
        _questions = loaded;
        _phase = Phase.playing;
      });
    } on FormatException catch (error) {
      _requestFailed(error.message, operation, uid);
    } on TimeoutException {
      _requestFailed('Request timed out after 10 seconds.', operation, uid);
    } catch (error) {
      _requestFailed('Request failed: $error', operation, uid);
    }
  }

  void _requestFailed(String message, int operation, String uid) {
    if (!_current(operation, uid)) return;
    setState(() {
      _fetching = false;
      _error = message;
      _phase = Phase.requestError;
    });
  }

  Future<void> _retryRequest() async {
    if (_phase != Phase.requestError) return;
    final operation = _operation;
    final uid = widget.user.uid;
    setState(() => _phase = Phase.loading);
    await Future<void>.delayed(const Duration(seconds: 5));
    if (_current(operation, uid)) await _startRound();
  }

  void _answer(int choice) {
    if (_phase != Phase.playing || _picked != null) return;
    final question = _questions[_index];
    if (choice < 0 || choice >= question.choices.length) return;
    setState(() {
      _picked = choice;
      _selections.add(choice);
      if (question.choices[choice] == question.correct) _score++;
    });
  }

  void _next() {
    if (_phase != Phase.playing || _picked == null) return;
    setState(() {
      if (_index + 1 == _questions.length) {
        _payload = Map<String, dynamic>.unmodifiable({
          'schemaVersion': 1,
          'variant': 'A',
          'categoryId': 9,
          'questionCount': _questions.length,
          'correctCount': _score,
          'submittedAt': FieldValue.serverTimestamp(),
        });
        _phase = Phase.readyToSubmit;
      } else {
        _index++;
        _picked = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_phase != Phase.readyToSubmit && _phase != Phase.notSaved) return;
    final payload = _payload;
    if (payload == null) return;
    final uid = widget.user.uid;
    final operation = _operation;
    final roundId = _roundId;
    final fault = _fault;
    setState(() {
      _phase = Phase.submitting;
      _error = null;
    });
    try {
      if (fault == Fault.unavailable) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Injected fault',
        );
      }
      if (fault == Fault.resourceExhausted) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'resource-exhausted',
          message: 'Injected fault',
        );
      }
      final outcome = await _repo
          .commit(uid: uid, roundId: roundId, payload: payload)
          .timeout(const Duration(seconds: 15));
      if (!_current(operation, uid)) return;
      if (outcome == CommitOutcome.collision) {
        setState(() => _phase = Phase.collision);
        return;
      }
      if (fault == Fault.staleResponse && !_lostAckFired) {
        _lostAckFired = true;
        await FirebaseAuth.instance.signOut();
        await Future<void>.delayed(const Duration(seconds: 5));
        if (!_current(operation, uid)) return;
        return;
      }
      if (fault == Fault.lostAck && !_lostAckFired) {
        _lostAckFired = true;
        setState(() {
          _error =
              'Injected lost acknowledgement after the transaction returned.';
          _phase = Phase.saveUnknown;
        });
        return;
      }
      await _verify(operation, uid, roundId, payload);
    } on FirebaseException catch (error) {
      if (!_current(operation, uid)) return;
      setState(() {
        _error = '${error.code}: ${error.message ?? ''}';
        _phase = error.code == 'permission-denied'
            ? Phase.permissionDenied
            : Phase.saveUnknown;
      });
    } catch (error) {
      if (!_current(operation, uid)) return;
      setState(() {
        _error = error is TimeoutException
            ? 'Submission timed out; the outcome is unknown.'
            : '$error';
        _phase = Phase.saveUnknown;
      });
    }
  }

  Future<void> _verify(
    int operation,
    String uid,
    String roundId,
    Map<String, dynamic> payload,
  ) async {
    if (!_current(operation, uid)) return;
    setState(() => _phase = Phase.verifying);
    try {
      final check = await _repo.verify(
        uid: uid,
        roundId: roundId,
        expectedPayload: payload,
      );
      if (!_current(operation, uid)) return;
      setState(() {
        _verification = check;
        if (check.result == VerifyResult.verified) {
          _phase = Phase.cloudVerified;
          _error = null;
        } else if (check.result == VerifyResult.missing) {
          _phase = Phase.notSaved;
          _error = 'No document was found on the server. Retry uses the same round ID.';
        } else if (check.result == VerifyResult.mismatch) {
          _phase = Phase.collision;
        } else {
          _phase = Phase.verificationUnavailable;
          _error = 'Read-back was inconclusive: ${check.result.name}.';
        }
      });
    } catch (error) {
      if (!_current(operation, uid)) return;
      setState(() {
        _error = 'Server verification failed: $error';
        _phase = Phase.verificationUnavailable;
      });
    }
  }

  Future<void> _reconcile() async {
    if (_busy || _payload == null) return;
    await _verify(_operation, widget.user.uid, _roundId, _payload!);
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign-out failed: $error')));
    }
  }

  Future<void> _openSavedAttempt() async {
    if (_busy || _unresolved) return;
    final uid = widget.user.uid;
    final operation = _operation;
    String enteredId = '';
    final roundId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Open a saved attempt'),
          content: TextField(
            onChanged: (value) => enteredId = value,
            decoration: const InputDecoration(labelText: 'Full round ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, enteredId.trim()),
              child: const Text('Read from server'),
            ),
          ],
        );
      },
    );
    if (!mounted ||
        !_current(operation, uid) ||
        roundId == null ||
        roundId.isEmpty) {
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(roundId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid round ID.')));
      return;
    }
    setState(() => _checkingSaved = true);
    try {
      final check = await _repo.verify(uid: uid, roundId: roundId);
      if (!mounted || !_current(operation, uid)) return;
      setState(() => _checkingSaved = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              check.result == VerifyResult.verified
                  ? 'Saved attempt verified'
                  : 'Attempt not verified',
            ),
            content: SingleChildScrollView(
              child: Text(
                check.result == VerifyResult.verified
                    ? '${check.path}\nScore: ${check.correctCount} / 10\n${check.submittedAt!.toDate().toUtc()}'
                    : 'Server result: ${check.result.name}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted || !_current(operation, uid)) return;
      setState(() => _checkingSaved = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read attempt: $error')));
    }
  }

  String _suffix() {
    if (_roundId.length <= 6) return _roundId;
    return _roundId.substring(_roundId.length - 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICA16 Cloud Quiz'),
        actions: [
          PopupMenuButton<Fault>(
            tooltip: 'Fault injection: ${_fault.label}',
            enabled: !_busy,
            icon: const Icon(Icons.bug_report),
            initialValue: _fault,
            onSelected: (fault) => setState(() => _fault = fault),
            itemBuilder: (_) => [
              for (final fault in Fault.values)
                PopupMenuItem(value: fault, child: Text(fault.label)),
            ],
          ),
          IconButton(
            tooltip: 'Restart round',
            onPressed: _busy || _unresolved ? null : _startRound,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Open saved attempt',
            onPressed: _busy || _unresolved ? null : _openSavedAttempt,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy || _unresolved ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text('Fault: ${_fault.label}'),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${useEmulators ? 'LOCAL EMULATORS · ' : ''}UID: ${widget.user.uid}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: _checkingSaved
                  ? const Busy(text: 'Checking saved attempt…')
                  : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case Phase.loading:
        return const Busy(text: 'Fetching 10 questions…');
      case Phase.requestError:
        return _errorPanel(
          'Request failed',
          _error ?? '',
          'Retry in 5s',
          _retryRequest,
        );
      case Phase.playing:
        return _playView();
      case Phase.readyToSubmit:
        return _reviewView();
      case Phase.submitting:
        return const Busy(text: 'Committing attempt…');
      case Phase.verifying:
        return const Busy(text: 'Reading back from server…');
      case Phase.cloudVerified:
        return _verifiedView();
      case Phase.saveUnknown:
        return _errorPanel(
          'Save unknown',
          'The write may have committed. Keep round …${_suffix()} and reconcile.\n${_error ?? ''}',
          'Reconcile from server',
          _reconcile,
        );
      case Phase.notSaved:
        return _errorPanel(
          'Not found on server',
          _error ?? '',
          'Retry same attempt',
          _submit,
        );
      case Phase.collision:
        return _errorPanel(
          'Collision',
          'This round ID contains different values. The existing attempt was preserved.',
          'Start a new round',
          _startRound,
        );
      case Phase.permissionDenied:
        return _errorPanel(
          'Permission denied',
          _error ?? 'Rules rejected the request.',
          'Back to review',
          () => setState(() => _phase = Phase.readyToSubmit),
        );
      case Phase.verificationUnavailable:
        return _errorPanel(
          'Verification unavailable',
          _error ?? '',
          'Read back again',
          _reconcile,
        );
    }
  }

  Widget _errorPanel(
    String title,
    String detail,
    String button,
    VoidCallback action,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: action, child: Text(button)),
          ],
        ),
      ),
    );
  }

  Widget _playView() {
    final question = _questions[_index];
    final answered = _picked != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Question ${_index + 1} of ${_questions.length}'),
        LinearProgressIndicator(
          value: (_index + (answered ? 1 : 0)) / _questions.length,
        ),
        const SizedBox(height: 8),
        Text('Score $_score · round …${_suffix()}'),
        const SizedBox(height: 20),
        Text(
          question.prompt,
          style: const TextStyle(fontSize: 18, height: 1.35),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < question.choices.length; i++)
          _choiceTile(question, i),
        if (answered)
          FilledButton(
            onPressed: _next,
            child: Text(
              _index + 1 == _questions.length ? 'Review all answers' : 'Next',
            ),
          ),
      ],
    );
  }

  Widget _choiceTile(Question question, int choice) {
    final answered = _picked != null;
    final correct = question.choices[choice] == question.correct;
    Color border = const Color(0xFFD8D3E0);
    Color fill = Colors.white;
    IconData? icon;
    if (answered && correct) {
      border = const Color(0xFF2E7D32);
      fill = const Color(0xFFDDF1E1);
      icon = Icons.check_circle;
    } else if (answered && _picked == choice) {
      border = const Color(0xFFC62828);
      fill = const Color(0xFFF9DEDE);
      icon = Icons.cancel;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: answered ? null : () => _answer(choice),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(child: Text(question.choices[choice])),
              if (icon != null) Icon(icon, color: border, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Review — $_score / 10',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SelectableText('Round ID: $_roundId'),
        const SizedBox(height: 12),
        for (var i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${i + 1}. ${_questions[i].prompt}\n'
              'Yours: ${_questions[i].choices[_selections[i]]}\nCorrect: ${_questions[i].correct}',
            ),
          ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Submit attempt'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _startRound,
          child: const Text('Replay (new round ID)'),
        ),
      ],
    );
  }

  Widget _verifiedView() {
    final check = _verification!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 44),
        const SizedBox(height: 8),
        Text(
          'Cloud verified',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        SelectableText('Path: ${check.path}'),
        SelectableText('Round ID: $_roundId'),
        Text('correctCount: ${check.correctCount} / 10'),
        Text('submittedAt: ${check.submittedAt!.toDate().toUtc()}'),
        const SizedBox(height: 12),
        const Text(
          'Source.server read, matching fields, resolved timestamp, no pending writes.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _startRound,
          child: const Text('Play another round'),
        ),
      ],
    );
  }
}

class Busy extends StatelessWidget {
  const Busy({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text),
        ],
      ),
    );
  }
}
