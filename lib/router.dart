import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/user_details_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/post/create_post_screen.dart';
import 'screens/post/post_detail_screen.dart';
import 'screens/comments/comments_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',             builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login',        builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',     builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/user-details',
      builder: (_, state) {
        final data = state.extra as Map<String, String>? ?? {};
        return UserDetailsScreen(userData: data);
      },
    ),
    GoRoute(path: '/feed',         builder: (_, __) => const FeedScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(
      path: '/profile/:uid',
      builder: (_, state) => ProfileScreen(userId: state.pathParameters['uid']!),
    ),
    GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/create-post',  builder: (_, __) => const CreatePostScreen()),
    GoRoute(
      path: '/post/:postId',
      builder: (_, state) => PostDetailScreen(postId: state.pathParameters['postId']!),
    ),
    GoRoute(
      path: '/comments/:postId',
      builder: (_, state) => CommentsScreen(
        postId:    state.pathParameters['postId']!,
        postOwner: state.extra as String? ?? '',
      ),
    ),
  ],
);
