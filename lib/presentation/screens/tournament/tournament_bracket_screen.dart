import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/persona_provider.dart';
import '../../../data/models/tournament.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

// ─── Layout constants ────────────────────────────────────────

const double _headerHeight = 30.0;
const double _slotHeight = 22.0;
const double _slotWidth = 100.0;
const double _connectorWidth = 22.0;
const double _roundWidth = _slotWidth + _connectorWidth;
const double _centerWidth = 80.0;
const int _halfEntries = 512;
const double _totalHeight = _headerHeight + _halfEntries * _slotHeight;
const double _leftWidth = 10 * _roundWidth;
const double _totalWidth = _leftWidth + _centerWidth + _leftWidth;

// ─── Bracket slot model ──────────────────────────────────────

class _Slot {
  final String id;
  final String name;
  final bool isUser;
  bool eliminated = false;

  _Slot({
    required this.id,
    required this.name,
    required this.isUser,
  });
}

// ─── Screen ──────────────────────────────────────────────────

class TournamentBracketScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentBracketScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentBracketScreen> createState() =>
      _TournamentBracketScreenState();
}

class _TournamentBracketScreenState
    extends ConsumerState<TournamentBracketScreen> {
  final TransformationController _tc = TransformationController();
  bool _didInitialCenter = false;
  List<List<_Slot>> _bracket = [];
  List<List<double>> _yPos = [];

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // ── Build bracket data from tournament + name map ──────────

  List<List<_Slot>> _buildBracket(
      Tournament t, Map<String, String> names) {
    final all = <List<_Slot>>[];

    // Round 0 — 1024 initial entries
    all.add(t.bracket
        .map((e) => _Slot(
              id: e.participantId,
              name: names[e.participantId] ?? '',
              isUser: e.isUser,
            ))
        .toList());

    // Rounds 1-10
    for (int r = 0; r < 10; r++) {
      final prev = all[r];
      final rd =
          t.rounds.where((x) => x.roundNumber == r).firstOrNull;
      final next = <_Slot>[];

      for (int i = 0; i < prev.length; i += 2) {
        if (i + 1 >= prev.length) {
          next.add(_Slot(
              id: prev[i].id,
              name: prev[i].name,
              isUser: prev[i].isUser));
          continue;
        }

        if (rd != null && i ~/ 2 < rd.matches.length) {
          final m = rd.matches[i ~/ 2];
          final loserId = m.winnerId == m.participant1Id
              ? m.participant2Id
              : m.participant1Id;
          if (prev[i].id == loserId) prev[i].eliminated = true;
          if (prev[i + 1].id == loserId) {
            prev[i + 1].eliminated = true;
          }
          next.add(_Slot(
            id: m.winnerId,
            name: names[m.winnerId] ?? m.winnerName,
            isUser: m.winnerId == 'user',
          ));
        } else {
          next.add(_Slot(id: '', name: '', isUser: false));
        }
      }
      all.add(next);
    }
    return all;
  }

  // ── Precompute Y positions for 512-entry half ───────────

  List<List<double>> _yPositions() {
    final pos = <List<double>>[];
    pos.add(List.generate(
        _halfEntries, (i) => _headerHeight + i * _slotHeight + _slotHeight / 2));
    for (int r = 1; r <= 9; r++) {
      final p = pos[r - 1];
      final cur = <double>[];
      for (int i = 0; i < p.length; i += 2) {
        cur.add(i + 1 < p.length ? (p[i] + p[i + 1]) / 2 : p[i]);
      }
      pos.add(cur);
    }
    return pos;
  }

  // ── Center on user's bracket position ──────────────────────

  void _centerOnUser(Tournament t) {
    final mq = MediaQuery.of(context);
    final vw = mq.size.width;
    final vh = mq.size.height -
        AppBar().preferredSize.height -
        mq.padding.top -
        130;

    final yPos = _yPositions();
    final isLeftSide = t.userBracketPosition < _halfEntries;
    final halfPos = isLeftSide
        ? t.userBracketPosition
        : t.userBracketPosition - _halfEntries;

    final userY =
        _headerHeight + halfPos * _slotHeight + _slotHeight / 2;

    // Find user's latest round position
    final userRound = t.rounds.length;

    double userX;
    if (isLeftSide) {
      userX = userRound * _roundWidth + _slotWidth / 2;
    } else {
      userX = _leftWidth + _centerWidth +
          (9 - userRound) * _roundWidth + _connectorWidth + _slotWidth / 2;
    }

    // Clamp userRound to max visible
    if (userRound >= 10) {
      // User is in finals/champion area — center on trophy
      userX = _leftWidth + _centerWidth / 2;
      final centerY = yPos[9].isNotEmpty ? yPos[9][0] : _totalHeight / 2;
      final tx = (vw / 2 - userX).clamp(-_totalWidth + vw, 0.0);
      final ty = (vh / 2 - centerY).clamp(-_totalHeight + vh, 0.0);
      _tc.value = Matrix4.translationValues(tx, ty, 0);
      return;
    }

    final tx = (vw / 2 - userX).clamp(-_totalWidth + vw, 0.0);
    final ty = (vh / 2 - userY).clamp(-_totalHeight + vh, 0.0);
    _tc.value = Matrix4.translationValues(tx, ty, 0);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tAsync = ref.watch(tournamentByIdProvider(widget.tournamentId));
    final pAsync = ref.watch(personasProvider);

    return tAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        // Name map
        final names = <String, String>{'user': 'You'};
        if (pAsync is AsyncData) {
          for (final p in pAsync.value!) {
            names[p.id] = p.name;
          }
        }

        _bracket = _buildBracket(tournament, names);
        _yPos = _yPositions();
        final bracket = _bracket;
        final yPos = _yPos;

        // Initial center
        if (!_didInitialCenter) {
          _didInitialCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerOnUser(tournament);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tournament.status == TournamentStatus.completed
                ? 'Tournament Complete'
                : tournament.status.displayName),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/'),
            ),
            actions: [
              if (tournament.spectatorMode)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Spectator',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Compact info bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primary.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Text('Round ${tournament.rounds.length}/10',
                        style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text('${tournament.remainingParticipants} remaining',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),

              // User's next match
              if (tournament.status != TournamentStatus.completed &&
                  !tournament.spectatorMode) ...[
                _buildNextMatchBar(tournament, names),
              ],

              // Bracket canvas
              Expanded(
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(40),
                  minScale: 0.03,
                  maxScale: 2.5,
                  child: GestureDetector(
                    onTapUp: (details) =>
                        _onBracketTap(details.localPosition),
                    child: CustomPaint(
                      size: const Size(_totalWidth, _totalHeight),
                      painter: _BracketPainter(
                        bracket: bracket,
                        yPos: yPos,
                        completedRounds: tournament.rounds.length,
                      ),
                    ),
                  ),
                ),
              ),

              // Action button
              _buildActionButton(context, tournament),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: () => _centerOnUser(tournament),
            tooltip: 'Find me',
            child: const Icon(Icons.my_location),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  // ── Bracket tap handler ─────────────────────────────────────

  void _onBracketTap(Offset pos) {
    final tapX = pos.dx;
    final tapY = pos.dy;
    if (tapY < _headerHeight) return;

    String? slotId;

    if (tapX < _leftWidth) {
      // Left side
      final round = tapX ~/ _roundWidth;
      final slotStartX = round * _roundWidth;
      if (tapX < slotStartX || tapX > slotStartX + _slotWidth) return;
      if (round >= _bracket.length || round >= _yPos.length) return;

      final half = _bracket[round].length ~/ 2;
      final positions = _yPos[round];
      final idx = _findClosestY(positions, tapY);
      if (idx < 0 || idx >= half) return;
      slotId = _bracket[round][idx].id;
    } else if (tapX > _leftWidth + _centerWidth) {
      // Right side
      final relX = tapX - (_leftWidth + _centerWidth);
      final col = relX ~/ _roundWidth;
      final round = 9 - col;
      final slotStartX =
          _leftWidth + _centerWidth + col * _roundWidth + _connectorWidth;
      if (tapX < slotStartX || tapX > slotStartX + _slotWidth) return;
      if (round < 0 || round >= _bracket.length || round >= _yPos.length) {
        return;
      }

      final half = _bracket[round].length ~/ 2;
      final positions = _yPos[round];
      final idx = _findClosestY(positions, tapY);
      if (idx < 0 || idx >= positions.length) return;
      slotId = _bracket[round][half + idx].id;
    }

    if (slotId == null || slotId.isEmpty || slotId == 'user') return;
    _showPersonaDetail(slotId);
  }

  int _findClosestY(List<double> positions, double tapY) {
    int best = -1;
    double bestDist = _slotHeight / 2;
    for (int i = 0; i < positions.length; i++) {
      final dist = (positions[i] - tapY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  void _showPersonaDetail(String personaId) async {
    final persona = await ref.read(personaProvider(personaId).future);
    if (persona == null || !mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                persona.country,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(persona.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Win Rate', persona.winRatePercentage),
            const SizedBox(height: 8),
            _infoRow('Speed', persona.speedDescription),
            const SizedBox(height: 8),
            _infoRow('Country', persona.country),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Next-match bar ────────────────────────────────────────

  Widget _buildNextMatchBar(Tournament t, Map<String, String> names) {
    final oppId = t.userOpponentId;
    if (oppId == null) return const SizedBox();
    final oppName = names[oppId] ?? 'AI';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Card(
        color: AppColors.primary.withValues(alpha: 0.1),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.sports_mma, color: AppColors.primary),
          title: Text('You vs $oppName',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(t.status.displayName),
        ),
      ),
    );
  }

  // ── Action button ──────────────────────────────────────────

  Widget _buildActionButton(BuildContext context, Tournament t) {
    if (t.status == TournamentStatus.completed) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                context.push('/results/${widget.tournamentId}'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('View Results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (t.spectatorMode) {
              context.push('/spectator/${widget.tournamentId}');
            } else {
              context.push('/match/${widget.tournamentId}');
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor:
                t.spectatorMode ? AppColors.secondary : AppColors.primary,
          ),
          child: Text(
            t.spectatorMode ? 'Watch' : 'Start Match',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ─── CustomPainter ───────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final List<List<_Slot>> bracket;
  final List<List<double>> yPos;
  final int completedRounds;

  // Cached colours
  static const _userCol = Color(0xFF6366F1);
  static const _userBg = Color(0x1A6366F1);
  static const _textCol = Color(0xFF1E293B);
  static const _elimCol = Color(0xFFBDBDBD);
  static const _tbdCol = Color(0xFF94A3B8);
  static const _lineCompleted = Color(0xFFCBD5E1);
  static const _lineFuture = Color(0xFFE2E8F0);
  static const _headerBg = Color(0xFFF1F5F9);
  static const _goldCol = Color(0xFFFFD700);

  _BracketPainter({
    required this.bracket,
    required this.yPos,
    required this.completedRounds,
  });

  // Right-side X origin (after left side + center)
  double get _rightOrigin => _leftWidth + _centerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    _paintHeaders(canvas);
    _paintLeftSide(canvas);
    _paintRightSide(canvas);
    _paintCenter(canvas);
  }

  // ── Round headers ──────────────────────────────────────────

  void _paintHeaders(Canvas canvas) {
    final bg = Paint()..color = _headerBg;
    final labels = AppConstants.roundNames; // 10 labels: R1024..Finals

    // Left headers (L→R, rounds 0-9)
    for (int r = 0; r < labels.length && r < 10; r++) {
      final x = r * _roundWidth;
      canvas.drawRect(
          Rect.fromLTWH(x, 0, _slotWidth, _headerHeight), bg);
      _drawText(
        canvas,
        labels[r],
        Offset(x + 3, 0),
        _slotWidth - 6,
        _headerHeight,
        const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            color: _textCol),
        verticalCenter: true,
      );
    }

    // Center header
    final cx = _leftWidth;
    canvas.drawRect(
        Rect.fromLTWH(cx, 0, _centerWidth, _headerHeight), bg);
    _drawText(
      canvas,
      'Champion',
      Offset(cx + 3, 0),
      _centerWidth - 6,
      _headerHeight,
      const TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          color: _textCol),
      verticalCenter: true,
      center: true,
    );

    // Right headers (mirrored: round 9 near center, round 0 on far right)
    for (int r = 0; r < labels.length && r < 10; r++) {
      final x = _rightOrigin + (9 - r) * _roundWidth + _connectorWidth;
      canvas.drawRect(
          Rect.fromLTWH(x, 0, _slotWidth, _headerHeight), bg);
      _drawText(
        canvas,
        labels[r],
        Offset(x + 3, 0),
        _slotWidth - 6,
        _headerHeight,
        const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            color: _textCol),
        verticalCenter: true,
      );
    }
  }

  // ── Left side (rounds 0-9, upper half) ─────────────────────

  void _paintLeftSide(Canvas canvas) {
    for (int r = 0; r <= 9 && r < bracket.length; r++) {
      final slots = bracket[r];
      final half = slots.length ~/ 2;
      final leftSlots = slots.sublist(0, half > 0 ? half : slots.length);
      final positions = yPos[r < yPos.length ? r : yPos.length - 1];

      // Paint slots
      for (int i = 0; i < leftSlots.length && i < positions.length; i++) {
        final s = leftSlots[i];
        final y = positions[i];
        final x = r * _roundWidth;

        _paintSlot(canvas, s, x, y);
      }

      // Paint connectors (to next round)
      if (r < 9 && r < bracket.length - 1) {
        final nextR = r + 1;
        final nextHalf = bracket[nextR].length ~/ 2;
        final nextSlots = bracket[nextR].sublist(0, nextHalf > 0 ? nextHalf : bracket[nextR].length);
        final nextPos = yPos[nextR < yPos.length ? nextR : yPos.length - 1];

        for (int i = 0; i < leftSlots.length - 1; i += 2) {
          final y1 = positions[i];
          final y2 = positions[i + 1];
          final ni = i ~/ 2;
          if (ni >= nextPos.length) break;
          final ym = nextPos[ni];
          final x = r * _roundWidth + _slotWidth;

          final isUser = leftSlots[i].isUser ||
              leftSlots[i + 1].isUser ||
              (ni < nextSlots.length && nextSlots[ni].isUser);
          final done = r < completedRounds;

          _paintConnectorLR(canvas, x, y1, y2, ym, isUser, done);
        }
      }
    }
  }

  // ── Right side (rounds 0-9, lower half, mirrored) ──────────

  void _paintRightSide(Canvas canvas) {
    for (int r = 0; r <= 9 && r < bracket.length; r++) {
      final slots = bracket[r];
      final half = slots.length ~/ 2;
      final rightSlots = slots.sublist(half);
      final positions = yPos[r < yPos.length ? r : yPos.length - 1];

      // X for right-side round r: slot starts after connector
      final slotX = _rightOrigin + (9 - r) * _roundWidth + _connectorWidth;

      for (int i = 0; i < rightSlots.length && i < positions.length; i++) {
        final s = rightSlots[i];
        final y = positions[i];

        _paintSlot(canvas, s, slotX, y, rightAligned: true);
      }

      // Paint connectors (mirrored, going left toward center)
      if (r < 9 && r < bracket.length - 1) {
        final nextR = r + 1;
        final nextHalf = bracket[nextR].length ~/ 2;
        final nextSlots = bracket[nextR].sublist(nextHalf);
        final nextPos = yPos[nextR < yPos.length ? nextR : yPos.length - 1];

        for (int i = 0; i < rightSlots.length - 1; i += 2) {
          final y1 = positions[i];
          final y2 = positions[i + 1];
          final ni = i ~/ 2;
          if (ni >= nextPos.length) break;
          final ym = nextPos[ni];

          // Connector column is to the LEFT of the slot
          final connRight = slotX; // connector ends at slot left edge
          final connLeft = connRight - _connectorWidth;

          final isUser = rightSlots[i].isUser ||
              rightSlots[i + 1].isUser ||
              (ni < nextSlots.length && nextSlots[ni].isUser);
          final done = r < completedRounds;

          _paintConnectorRL(canvas, connLeft, connRight, y1, y2, ym, isUser, done);
        }
      }
    }
  }

  // ── Center (trophy + champion + finals connectors) ─────────

  void _paintCenter(Canvas canvas) {
    final centerX = _leftWidth;
    final centerMidX = centerX + _centerWidth / 2;
    final centerY = yPos.last.isNotEmpty
        ? yPos.last[0]
        : _totalHeight / 2;

    // Trophy emoji
    _drawText(
      canvas,
      '\u{1F3C6}', // 🏆
      Offset(centerMidX - 20, centerY - 28),
      40,
      28,
      const TextStyle(fontSize: 24),
      verticalCenter: true,
      center: true,
    );

    // Champion name
    if (bracket.length > 10 && bracket[10].isNotEmpty) {
      final champion = bracket[10][0];
      if (champion.id.isNotEmpty) {
        final style = TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: champion.isUser ? _userCol : _textCol,
        );
        _drawText(
          canvas,
          champion.name,
          Offset(centerX + 4, centerY + 2),
          _centerWidth - 8,
          _slotHeight,
          style,
          verticalCenter: true,
          center: true,
        );
      }
    }

    // Connector from left finalist to center
    if (bracket.length > 9 && bracket[9].isNotEmpty) {
      final leftFinalist = bracket[9][0];
      final leftFinalistX = 9 * _roundWidth + _slotWidth;
      final leftFinalistY = centerY;

      final isUser = leftFinalist.isUser;
      final done = completedRounds > 9;

      final p = _connectorPaint(isUser, done);
      canvas.drawLine(
        Offset(leftFinalistX, leftFinalistY),
        Offset(centerX, leftFinalistY),
        p,
      );
    }

    // Connector from right finalist to center
    if (bracket.length > 9 && bracket[9].length > 1) {
      final rightFinalist = bracket[9][1];
      final rightFinalistX = _rightOrigin + _connectorWidth;
      final rightFinalistY = centerY;

      final isUser = rightFinalist.isUser;
      final done = completedRounds > 9;

      final p = _connectorPaint(isUser, done);
      canvas.drawLine(
        Offset(centerX + _centerWidth, rightFinalistY),
        Offset(rightFinalistX, rightFinalistY),
        p,
      );
    }

    // Gold ring around trophy area if champion exists
    if (bracket.length > 10 && bracket[10].isNotEmpty && bracket[10][0].id.isNotEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerMidX, centerY - 10),
            width: 50,
            height: 50,
          ),
          const Radius.circular(25),
        ),
        Paint()
          ..color = _goldCol.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  // ── Shared slot painting ──────────────────────────────────

  void _paintSlot(Canvas canvas, _Slot s, double x, double y, {bool rightAligned = false}) {
    // User highlight bg
    if (s.isUser && !s.eliminated) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x + _slotWidth / 2, y),
              width: _slotWidth,
              height: _slotHeight - 2),
          const Radius.circular(3),
        ),
        Paint()..color = _userBg,
      );
    }

    Color col;
    FontWeight fw;
    if (s.id.isEmpty) {
      col = _tbdCol;
      fw = FontWeight.normal;
    } else if (s.eliminated) {
      col = _elimCol;
      fw = FontWeight.normal;
    } else if (s.isUser) {
      col = _userCol;
      fw = FontWeight.bold;
    } else {
      col = _textCol;
      fw = FontWeight.normal;
    }

    _drawText(
      canvas,
      s.id.isEmpty ? '\u2014' : s.name,
      Offset(x + 3, y - _slotHeight / 2),
      _slotWidth - 6,
      _slotHeight,
      TextStyle(fontSize: 9, color: col, fontWeight: fw),
      verticalCenter: true,
      rightAligned: rightAligned,
    );
  }

  // ── Left-to-right connector (left side) ───────────────────

  void _paintConnectorLR(Canvas canvas, double x, double y1, double y2,
      double ym, bool isUser, bool done) {
    final p = _connectorPaint(isUser, done);

    final mid = x + _connectorWidth / 2;
    canvas.drawLine(Offset(x, y1), Offset(mid, y1), p);
    canvas.drawLine(Offset(x, y2), Offset(mid, y2), p);
    canvas.drawLine(Offset(mid, y1), Offset(mid, y2), p);
    canvas.drawLine(Offset(mid, ym), Offset(x + _connectorWidth, ym), p);
  }

  // ── Right-to-left connector (right side, mirrored) ────────

  void _paintConnectorRL(Canvas canvas, double connLeft, double connRight,
      double y1, double y2, double ym, bool isUser, bool done) {
    final p = _connectorPaint(isUser, done);

    final mid = connLeft + _connectorWidth / 2;
    canvas.drawLine(Offset(connRight, y1), Offset(mid, y1), p);
    canvas.drawLine(Offset(connRight, y2), Offset(mid, y2), p);
    canvas.drawLine(Offset(mid, y1), Offset(mid, y2), p);
    canvas.drawLine(Offset(mid, ym), Offset(connLeft, ym), p);
  }

  // ── Connector paint helper ────────────────────────────────

  Paint _connectorPaint(bool isUser, bool done) {
    Color lc;
    double lw;
    if (isUser) {
      lc = _userCol;
      lw = 1.5;
    } else if (done) {
      lc = _lineCompleted;
      lw = 0.7;
    } else {
      lc = _lineFuture;
      lw = 0.5;
    }
    return Paint()
      ..color = lc
      ..strokeWidth = lw
      ..style = PaintingStyle.stroke;
  }

  // ── Text helper ────────────────────────────────────────────

  void _drawText(
    Canvas canvas,
    String text,
    Offset topLeft,
    double maxW,
    double boxH,
    TextStyle style, {
    bool verticalCenter = false,
    bool rightAligned = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '\u2026',
    )..layout(maxWidth: maxW);

    final dy =
        verticalCenter ? topLeft.dy + (boxH - tp.height) / 2 : topLeft.dy;

    double dx = topLeft.dx;
    if (center) {
      dx = topLeft.dx + (maxW - tp.width) / 2;
    } else if (rightAligned) {
      dx = topLeft.dx + maxW - tp.width;
    }

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      completedRounds != old.completedRounds ||
      bracket.length != old.bracket.length;
}
