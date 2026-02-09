import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/project_creation/project_creation_screen.dart';
import '../screens/project_detail/project_detail_screen.dart';
import '../screens/personas/personas_screen.dart';
import '../screens/user_profile/user_profile_screen.dart';
import '../screens/pre_match/pre_match_screen.dart';
import '../screens/tournament/tournament_bracket_screen.dart';
import '../screens/tournament/match_screen.dart';
import '../screens/victory/victory_screen.dart';
import '../screens/spectator/spectator_screen.dart';
import '../screens/results/results_screen.dart';
import '../screens/rankings/rankings_screen.dart';
import '../screens/analysis/weakness_analysis_screen.dart';
import '../screens/project_detail/add_questions_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/create-project',
        name: 'createProject',
        builder: (context, state) => const ProjectCreationScreen(),
      ),
      GoRoute(
        path: '/project/:id',
        name: 'projectDetail',
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return ProjectDetailScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/project/:id/add-questions',
        name: 'addQuestions',
        builder: (context, state) {
          final projectId = state.pathParameters['id']!;
          return AddQuestionsScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/personas',
        name: 'personas',
        builder: (context, state) => const PersonasScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'userProfile',
        builder: (context, state) => const UserProfileScreen(),
      ),
      GoRoute(
        path: '/pre-match/:projectId',
        name: 'preMatch',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return PreMatchScreen(projectId: projectId);
        },
      ),
      GoRoute(
        path: '/tournament/:tournamentId',
        name: 'tournamentBracket',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return TournamentBracketScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/match/:tournamentId',
        name: 'match',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return MatchScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/victory/:tournamentId',
        name: 'victory',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          final isChampion = state.uri.queryParameters['champion'] == 'true';
          return VictoryScreen(
            tournamentId: tournamentId,
            isChampion: isChampion,
          );
        },
      ),
      GoRoute(
        path: '/spectator/:tournamentId',
        name: 'spectator',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return SpectatorScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/results/:tournamentId',
        name: 'results',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return ResultsScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/analysis/:tournamentId',
        name: 'weaknessAnalysis',
        builder: (context, state) {
          final tournamentId = state.pathParameters['tournamentId']!;
          return WeaknessAnalysisScreen(tournamentId: tournamentId);
        },
      ),
      GoRoute(
        path: '/rankings/:projectId',
        name: 'rankings',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return RankingsScreen(projectId: projectId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
