import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppRoot());
}

/// =======================
/// APP ROOT (STATE ABOVE MaterialApp!)
/// =======================
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState()..seedDemoData();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: 'Dating',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        ),
        // home: const RootShell(),
        home: const LoginGate(signedInChild: RootShell()),
      ),
    );
  }
}

/// Fix: Web/desktop scrolling + dragging works with mouse/trackpad
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// =======================
/// APP STATE (no packages)
/// =======================
class AppState extends ChangeNotifier {
  bool isPro = false;

  // PRO settings/features
  bool incognito = false; // Pro-only
  bool travelMode = false; // Pro-only

  // Filters (Advanced Pro)
  int minAge = 18;
  int maxAge = 35;
  int maxDistanceKm = 25;

  // Limits (demo "per session")
  int likesUsed = 0;
  int superLikesUsed = 0;

  int get likeLimit => isPro ? 999999 : 10;
  int get superLikeLimit => isPro ? 5 : 1;
  bool get canRewind => isPro;
  bool get canSeeWhoLikedYou => isPro;

  // Discover data
  final List<Profile> allProfiles = [];
  final Set<String> passed = {}; // disliked
  final Set<String> liked = {}; // liked
  final Set<String> superLiked = {}; // superliked
  final Map<String, String> superLikeMessage = {}; // profileId -> message (Pro)

  // Undo stack
  final List<SwipeHistory> history = [];

  // Matches & chats
  final List<Match> matches = [];
  final Map<String, ChatThread> chatsByMatchId = {};

  // "Who liked you" (demo)
  final List<String> whoLikedYou = []; // profile ids (likes you)

  // Current user (demo)
  final UserAccount me = const UserAccount(
    id: "me",
    name: "Phillip",
    age: 19,
    bio: "-",
  );

  void seedDemoData() {
    allProfiles
      ..clear()
      ..addAll(const [
        Profile(
          id: "p1",
          name: "Lena",
          age: 22,
          distanceKm: 3,
          bio: "Kaffee, Gym, und ich liebe Roadtrips. 🚗✨",
          tags: ["Gym", "Roadtrips", "Kaffee"],
          photos: [
            "https://picsum.photos/seed/lena1/700/1100",
            "https://picsum.photos/seed/lena2/700/1100",
            "https://picsum.photos/seed/lena3/700/1100",
          ],
          likesYou: true,
        ),
        Profile(
          id: "p2",
          name: "Mia",
          age: 24,
          distanceKm: 7,
          bio: "Wenn du Hunde magst, sind wir schon fast ein Match. 🐶",
          tags: ["Hunde", "Spaziergänge", "Memes"],
          photos: [
            "https://picsum.photos/seed/mia1/700/1100",
            "https://picsum.photos/seed/mia2/700/1100",
            "https://picsum.photos/seed/mia3/700/1100",
          ],
          likesYou: false,
        ),
        Profile(
          id: "p3",
          name: "Sarah",
          age: 21,
          distanceKm: 5,
          bio: "Sushi > Pizza (sorry not sorry). 🍣",
          tags: ["Sushi", "Food", "City"],
          photos: [
            "https://picsum.photos/seed/sarah1/700/1100",
            "https://picsum.photos/seed/sarah2/700/1100",
            "https://picsum.photos/seed/sarah3/700/1100",
          ],
          likesYou: true,
        ),
        Profile(
          id: "p4",
          name: "Nina",
          age: 26,
          distanceKm: 11,
          bio: "Spontan. Ehrlich. Und ich lache zu laut. 😄",
          tags: ["Spontan", "Musik", "Laugh"],
          photos: [
            "https://picsum.photos/seed/nina1/700/1100",
            "https://picsum.photos/seed/nina2/700/1100",
            "https://picsum.photos/seed/nina3/700/1100",
          ],
          likesYou: false,
        ),
        Profile(
          id: "p5",
          name: "Eva",
          age: 29,
          distanceKm: 18,
          bio: "Berge, Sonnenuntergänge, gute Gespräche. 🌄",
          tags: ["Berge", "Natur", "Talks"],
          photos: [
            "https://picsum.photos/seed/eva1/700/1100",
            "https://picsum.photos/seed/eva2/700/1100",
            "https://picsum.photos/seed/eva3/700/1100",
          ],
          likesYou: true,
        ),
      ]);

    whoLikedYou
      ..clear()
      ..addAll(allProfiles.where((p) => p.likesYou).map((p) => p.id));

    passed.clear();
    liked.clear();
    superLiked.clear();
    superLikeMessage.clear();
    history.clear();
    matches.clear();
    chatsByMatchId.clear();
    likesUsed = 0;
    superLikesUsed = 0;

    notifyListeners();
  }

  // Filtering for Discover
  List<Profile> get discoverQueue {
    return allProfiles.where((p) {
      if (passed.contains(p.id) || liked.contains(p.id) || superLiked.contains(p.id)) return false;
      if (isPro) {
        if (p.age < minAge || p.age > maxAge) return false;
        if (p.distanceKm > maxDistanceKm) return false;
      }
      return true;
    }).toList();
  }

  Profile? get currentProfile => discoverQueue.isNotEmpty ? discoverQueue.first : null;
  Profile? get nextProfile => discoverQueue.length > 1 ? discoverQueue[1] : null;

  bool canUseLike() => likesUsed < likeLimit;
  bool canUseSuperLike() => superLikesUsed < superLikeLimit;

  void togglePro(bool value) {
    isPro = value;
    if (!isPro) {
      incognito = false;
      travelMode = false;
    }
    notifyListeners();
  }

  void toggleIncognito(bool value) {
    if (!isPro) return;
    incognito = value;
    notifyListeners();
  }

  void toggleTravelMode(bool value) {
    if (!isPro) return;
    travelMode = value;
    notifyListeners();
  }

  void updateFilters({int? minA, int? maxA, int? maxDist}) {
    if (!isPro) return;
    if (minA != null) minAge = minA;
    if (maxA != null) maxAge = maxA;
    if (maxDist != null) maxDistanceKm = maxDist;
    if (minAge > maxAge) {
      final t = minAge;
      minAge = maxAge;
      maxAge = t;
    }
    notifyListeners();
  }

  /// Swipe actions
  SwipeResult likeCurrent() {
    final p = currentProfile;
    if (p == null) return SwipeResult.none;
    if (!canUseLike()) return SwipeResult.limitLike;

    likesUsed++;
    liked.add(p.id);
    history.add(SwipeHistory(profileId: p.id, action: SwipeAction.like));
    notifyListeners();

    return _maybeMatch(p, isSuper: false);
  }

  SwipeResult dislikeCurrent() {
    final p = currentProfile;
    if (p == null) return SwipeResult.none;

    passed.add(p.id);
    history.add(SwipeHistory(profileId: p.id, action: SwipeAction.dislike));
    notifyListeners();
    return SwipeResult.disliked;
  }

  SwipeResult superLikeCurrent({String? message}) {
    final p = currentProfile;
    if (p == null) return SwipeResult.none;
    if (!canUseSuperLike()) return SwipeResult.limitSuper;

    superLikesUsed++;
    superLiked.add(p.id);
    if (isPro && message != null && message.trim().isNotEmpty) {
      superLikeMessage[p.id] = message.trim();
    }
    history.add(SwipeHistory(profileId: p.id, action: SwipeAction.superLike));
    notifyListeners();

    return _maybeMatch(p, isSuper: true);
  }

  SwipeResult rewind() {
    if (!canRewind) return SwipeResult.lockedRewind;
    if (history.isEmpty) return SwipeResult.none;

    final last = history.removeLast();
    final id = last.profileId;

    switch (last.action) {
      case SwipeAction.like:
        if (liked.remove(id)) likesUsed = max(0, likesUsed - 1);
        break;
      case SwipeAction.superLike:
        if (superLiked.remove(id)) superLikesUsed = max(0, superLikesUsed - 1);
        superLikeMessage.remove(id);
        break;
      case SwipeAction.dislike:
        passed.remove(id);
        break;
    }

    matches.removeWhere((m) => m.profileId == id);
    chatsByMatchId.removeWhere((matchId, chat) => chat.profileId == id);

    notifyListeners();
    return SwipeResult.rewinded;
  }

  SwipeResult _maybeMatch(Profile p, {required bool isSuper}) {
    if (p.likesYou) {
      final matchId = "m_${p.id}";
      if (!matches.any((m) => m.id == matchId)) {
        final msg = isPro ? superLikeMessage[p.id] : null;

        matches.insert(
          0,
          Match(id: matchId, profileId: p.id, createdAt: DateTime.now(), superLikeNote: msg),
        );

        chatsByMatchId[matchId] = ChatThread(
          id: matchId,
          profileId: p.id,
          messages: [
            ChatMessage(
              id: "sys1",
              fromMe: false,
              text: "Hey 👋 Match! Lust zu schreiben?",
              at: DateTime.now(),
              seen: true,
            ),
            if (msg != null)
              ChatMessage(
                id: "sys2",
                fromMe: true,
                text: "Super Like Nachricht: “$msg”",
                at: DateTime.now(),
                seen: true,
              ),
          ],
        );
      }
      notifyListeners();
      return SwipeResult.matched;
    }

    return isSuper ? SwipeResult.superLiked : SwipeResult.liked;
  }

  Profile profileById(String id) {
    return allProfiles.firstWhere((p) => p.id == id, orElse: () => const Profile.empty());
  }

  // Chat actions
  void sendMessage(String matchId, String text, {bool proReadReceipt = false}) {
    final thread = chatsByMatchId[matchId];
    if (thread == null) return;

    final msg = ChatMessage(
      id: "msg_${DateTime.now().microsecondsSinceEpoch}",
      fromMe: true,
      text: text,
      at: DateTime.now(),
      seen: proReadReceipt ? false : true,
    );

    thread.messages.add(msg);

    thread.messages.add(
      ChatMessage(
        id: "msg_${DateTime.now().microsecondsSinceEpoch}_r",
        fromMe: false,
        text: _autoReply(text),
        at: DateTime.now().add(const Duration(seconds: 1)),
        seen: true,
      ),
    );

    notifyListeners();
  }

  String _autoReply(String text) {
    final t = text.toLowerCase();
    if (t.contains("hi") || t.contains("hey")) return "Hey 😄 Wie läuft dein Tag?";
    if (t.contains("sushi")) return "Sushi klingt top! Lieblingsrolle?";
    if (t.contains("gym")) return "Nice! Trainierst du eher Kraft oder Cardio?";
    return "Klingt gut 😊 Erzähl mehr!";
  }

  String generateIcebreaker(Profile p) {
    final tag = (p.tags.isNotEmpty) ? p.tags[Random().nextInt(p.tags.length)] : "Random";
    final starters = [
      "Kurze Frage: Was ist dein Top-1 bei “$tag”? 😄",
      "Wenn “$tag” heute ein Plan wäre – was machen wir? 👀",
      "Deal: Du erklärst mir “$tag”, ich bringe den Kaffee. ☕",
      "Was ist das Beste/Schlimmste, das dir bei “$tag” passiert ist? 😂",
    ];
    return starters[Random().nextInt(starters.length)];
  }
}

/// Simple InheritedNotifier
class AppStateScope extends InheritedNotifier<AppState> {
  final AppState state;

  const AppStateScope({
    super.key,
    required this.state,
    required Widget child,
  }) : super(notifier: state, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope.of() called with a context that does not contain AppStateScope.');
    return scope!.state;
  }
}

/// =======================
/// MODELS
/// =======================
class UserAccount {
  final String id;
  final String name;
  final int age;
  final String bio;

  const UserAccount({
    required this.id,
    required this.name,
    required this.age,
    required this.bio,
  });
}

class Profile {
  final String id;
  final String name;
  final int age;
  final int distanceKm;
  final String bio;
  final List<String> tags;
  final List<String> photos;
  final bool likesYou;

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.distanceKm,
    required this.bio,
    required this.tags,
    required this.photos,
    required this.likesYou,
  });

  const Profile.empty()
      : id = "",
        name = "",
        age = 0,
        distanceKm = 0,
        bio = "",
        tags = const [],
        photos = const [],
        likesYou = false;
}

class Match {
  final String id;
  final String profileId;
  final DateTime createdAt;
  final String? superLikeNote;

  Match({
    required this.id,
    required this.profileId,
    required this.createdAt,
    this.superLikeNote,
  });
}

class ChatThread {
  final String id;
  final String profileId;
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    required this.profileId,
    required this.messages,
  });
}

class ChatMessage {
  final String id;
  final bool fromMe;
  final String text;
  final DateTime at;
  bool seen;

  ChatMessage({
    required this.id,
    required this.fromMe,
    required this.text,
    required this.at,
    required this.seen,
  });
}

enum SwipeAction { like, dislike, superLike }

class SwipeHistory {
  final String profileId;
  final SwipeAction action;

  SwipeHistory({required this.profileId, required this.action});
}

enum SwipeResult {
  none,
  liked,
  superLiked,
  disliked,
  matched,
  limitLike,
  limitSuper,
  lockedRewind,
  rewinded,
}

/// =======================
/// ROOT SHELL (WEB/DESKTOP layout + mobile bottom nav)
/// =======================
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  bool _isDesktop(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 900; // desktop breakpoint
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    final pages = const [
      DiscoverPage(),
      ChatsPage(),
      AccountPage(),
    ];

    // Desktop/Web -> NavigationRail + centered content (looks like web app)
    if (desktop) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0B10), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Container(
                  width: 84,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.25),
                    border: Border(right: BorderSide(color: Colors.white.withOpacity(.08))),
                  ),
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => index = i),
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Icon(Icons.local_fire_department, color: Colors.white.withOpacity(.9)),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.local_fire_department),
                        label: Text("Discover"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        label: Text("Chats"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        label: Text("Account"),
                      ),
                    ],
                    selectedIconTheme: const IconThemeData(color: Colors.pinkAccent),
                    unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(.75)),
                    selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    unselectedLabelTextStyle:
                        TextStyle(color: Colors.white.withOpacity(.65), fontWeight: FontWeight.w700),
                  ),
                ),

                // Content area (centered)
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.04),
                              border: Border.all(color: Colors.white.withOpacity(.08)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(index),
                                child: pages[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile -> bottom navigation (as before)
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0B10), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: index,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_fire_department), label: "Discover"),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: "Chats"),
          NavigationDestination(icon: Icon(Icons.person_outline), label: "Account"),
        ],
      ),
    );
  }
}

/// =======================
/// DISCOVER (SWIPE) + PERF + DESKTOP SHORTCUTS
/// - Throttled pan updates (~60fps)
/// - RepaintBoundary around card transform
/// - Precache current + next images to reduce stutter
/// - Keyboard shortcuts on desktop/web:
///   A/Left = Nope, D/Right = Like, W/Up = Super, Z = Rewind, ←/→ photo
/// =======================
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  double _angle = 0;
  bool _isAnimating = false;

  late final AnimationController _controller;
  Animation<Offset>? _offsetAnim;
  Animation<double>? _angleAnim;

  int _photoIndex = 0;

  static const double _swipeThreshold = 120;
  static const double _maxAngleDeg = 14;

  int _lastFrameMs = 0; // throttle for web/desktop

  String _lastPrefetchKey = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: kIsWeb ? 280 : 220),
    )
      ..addListener(() {
        if (_offsetAnim != null) {
          setState(() {
            _offset = _offsetAnim!.value;
            _angle = _angleAnim?.value ?? _angle;
          });
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          _isAnimating = false;
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 900;

  double _degToRad(double deg) => deg * pi / 180.0;

  void _animateTo(Offset target, double angle, VoidCallback onDone) {
    _isAnimating = true;
    _controller.stop();
    _controller.reset();

    _offsetAnim = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _angleAnim = Tween<double>(begin: _angle, end: angle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().whenComplete(onDone);
  }

  void _resetCard() {
    setState(() {
      _offset = Offset.zero;
      _angle = 0;
      _photoIndex = 0;
    });
  }

  void _topToast(BuildContext context, String text) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 12,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: kIsWeb
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(.12)),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 950), entry.remove);
  }

  Future<String?> _askSuperLikeMessage(BuildContext context) async {
    final state = AppStateScope.of(context);
    if (!state.isPro) return null;

    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Super Like Nachricht"),
        content: TextField(
          controller: c,
          maxLength: 120,
          decoration: const InputDecoration(
            hintText: "Z.B. „Dein Profil ist mega – Kaffee diese Woche?“",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Skip")),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text("Senden")),
        ],
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    final state = AppStateScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PaywallSheet(state: state),
    );
  }

  void _handleSwipeResult(BuildContext context, SwipeResult result) {
    final state = AppStateScope.of(context);

    switch (result) {
      case SwipeResult.limitLike:
        _topToast(context, "Like-Limit erreicht 🔒 (Pro = unbegrenzt)");
        _showPaywall(context);
        _resetCard();
        return;
      case SwipeResult.limitSuper:
        _topToast(context, "Superlike-Limit erreicht 🔒 (Pro = 5/Tag)");
        _showPaywall(context);
        _resetCard();
        return;
      case SwipeResult.lockedRewind:
        _topToast(context, "Rewind ist Pro 🔒");
        _showPaywall(context);
        return;
      case SwipeResult.rewinded:
        _topToast(context, "Rewind ✅");
        _resetCard();
        return;
      case SwipeResult.matched:
        _topToast(context, "MATCH ✅ Öffne Chats!");
        _resetCard();
        return;
      case SwipeResult.liked:
        _topToast(context, "LIKE ❤️ • ${state.likesUsed}/${state.likeLimit}");
        _resetCard();
        return;
      case SwipeResult.superLiked:
        _topToast(context, "SUPER LIKE ⭐ • ${state.superLikesUsed}/${state.superLikeLimit}");
        _resetCard();
        return;
      case SwipeResult.disliked:
        _topToast(context, "NOPE ❌");
        _resetCard();
        return;
      default:
        return;
    }
  }

  void _panUpdateThrottled(DragUpdateDetails d, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < 16) return; // ~60fps
    _lastFrameMs = now;

    setState(() {
      _offset += d.delta;
      final normalized = (_offset.dx / max(1.0, size.width)).clamp(-1.0, 1.0);
      _angle = _degToRad(_maxAngleDeg) * normalized;
    });
  }

  void _precacheFor(Profile? current, Profile? next) {
    if (!mounted) return;
    if (current == null) return;

    final key = "${current.id}|${next?.id ?? ""}";
    if (_lastPrefetchKey == key) return;
    _lastPrefetchKey = key;

    // Preload: current photo 0 + next photo 0 (reduces swipe stutter)
    if (current.photos.isNotEmpty) {
      precacheImage(NetworkImage(current.photos.first), context);
      // also next photo to reduce "photo tap" hitch
      if (current.photos.length > 1) {
        precacheImage(NetworkImage(current.photos[1]), context);
      }
    }
    if (next != null && next.photos.isNotEmpty) {
      precacheImage(NetworkImage(next.photos.first), context);
    }
  }

  void _photoPrev(Profile current) {
    if (current.photos.length <= 1) return;
    setState(() => _photoIndex = max(0, _photoIndex - 1));
  }

  void _photoNext(Profile current) {
    if (current.photos.length <= 1) return;
    setState(() => _photoIndex = min(current.photos.length - 1, _photoIndex + 1));
  }

  Future<void> _doSuperLike(BuildContext context, AppState state) async {
    String? msg;
    if (state.isPro) msg = await _askSuperLikeMessage(context);
    _animateTo(const Offset(0, -720), 0, () {
      final r = state.superLikeCurrent(message: msg);
      _handleSwipeResult(context, r);
    });
  }

  void _doLike(BuildContext context, AppState state) {
    _animateTo(const Offset(720, 30), _degToRad(_maxAngleDeg), () {
      final r = state.likeCurrent();
      _handleSwipeResult(context, r);
    });
  }

  void _doNope(BuildContext context, AppState state) {
    _animateTo(const Offset(-720, 30), _degToRad(-_maxAngleDeg), () {
      final r = state.dislikeCurrent();
      _handleSwipeResult(context, r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final current = state.currentProfile;
    final next = state.nextProfile;

    _precacheFor(current, next);

    final desktop = _isDesktop(context);

    // Desktop keyboard shortcuts
    return Focus(
      autofocus: desktop,
      onKeyEvent: (node, event) {
        if (!desktop) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_isAnimating) return KeyEventResult.handled;

        if (current != null) {
          final key = event.logicalKey.keyLabel.toLowerCase();

          // Photos
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _photoPrev(current);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _photoNext(current);
            return KeyEventResult.handled;
          }

          // Swipes (A/D/W/Z)
          if (key == "a") {
            _doNope(context, state);
            return KeyEventResult.handled;
          }
          if (key == "d") {
            _doLike(context, state);
            return KeyEventResult.handled;
          }
          if (key == "w") {
            _doSuperLike(context, state);
            return KeyEventResult.handled;
          }
          if (key == "z") {
            final r = state.rewind();
            _handleSwipeResult(context, r);
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          _DiscoverTopBar(
            isPro: state.isPro,
            onTapPro: () => _showPaywall(context),
            onTapFilters: () {
              if (!state.isPro) {
                _topToast(context, "Advanced Filter sind Pro 🔒");
                _showPaywall(context);
                return;
              }
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF0B0B10),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const FiltersSheet(),
              );
            },
          ),

          // Desktop: give more "web" spacing + info row
          if (desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    "Shortcuts: A=Nope • D=Like • W=Super • Z=Rewind • ←/→ Photos",
                    style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    state.isPro
                        ? "PRO: Unlimited Likes • Superlikes ${state.superLikesUsed}/${state.superLikeLimit}"
                        : "FREE: Likes ${state.likesUsed}/${state.likeLimit} • Superlikes ${state.superLikesUsed}/${state.superLikeLimit}",
                    style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Desktop card area shouldn't be full width
                  maxWidth: desktop ? 980 : (MediaQuery.of(context).size.width >= 700 ? 520 : 9999),
                ),
                child: desktop
                    // Desktop: card + right panel (web look)
                    ? Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _discoverCardArea(context, state, current, next, desktop),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 4,
                            child: _DiscoverSidePanel(
                              isPro: state.isPro,
                              likesUsed: state.likesUsed,
                              likeLimit: state.likeLimit,
                              onUpgrade: () => _showPaywall(context),
                              onRewind: () {
                                final r = state.rewind();
                                _handleSwipeResult(context, r);
                              },
                              onNope: () => _doNope(context, state),
                              onSuper: () => _doSuperLike(context, state),
                              onLike: () => _doLike(context, state),
                            ),
                          ),
                        ],
                      )
                    // Mobile: just card
                    : _discoverCardArea(context, state, current, next, desktop),
              ),
            ),
          ),

          // Mobile action row (desktop has side panel)
          if (!desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleBtn(
                    icon: Icons.undo,
                    color: state.isPro ? Colors.amberAccent : Colors.white38,
                    onTap: () {
                      final r = state.rewind();
                      _handleSwipeResult(context, r);
                    },
                  ),
                  _CircleBtn(
                    icon: Icons.close,
                    color: Colors.redAccent,
                    onTap: () => _doNope(context, state),
                  ),
                  _CircleBtn(
                    icon: Icons.star,
                    color: Colors.blueAccent,
                    onTap: () => _doSuperLike(context, state),
                  ),
                  _CircleBtn(
                    icon: Icons.favorite,
                    color: Colors.greenAccent,
                    onTap: () => _doLike(context, state),
                  ),
                ],
              ),
            ),

          if (!desktop)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                state.isPro
                    ? "PRO: Unlimited Likes • Superlikes ${state.superLikesUsed}/${state.superLikeLimit} • Rewind ✅"
                    : "FREE: Likes ${state.likesUsed}/${state.likeLimit} • Superlikes ${state.superLikesUsed}/${state.superLikeLimit} • Rewind 🔒",
                style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _discoverCardArea(
    BuildContext context,
    AppState state,
    Profile? current,
    Profile? next,
    bool desktop,
  ) {
    return AspectRatio(
      aspectRatio: desktop ? (4 / 5) : (MediaQuery.of(context).size.width >= 700 ? (3 / 4.2) : (3 / 4.7)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final size = Size(c.maxWidth, c.maxHeight);

            if (current == null) {
              return Center(
                child: Text(
                  "Keine Profile mehr",
                  style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 18),
                ),
              );
            }

            final photoIdx = _photoIndex.clamp(0, max(0, current.photos.length - 1)).toInt();

            return Stack(
              alignment: Alignment.center,
              children: [
                if (next != null)
                  Transform.scale(
                    scale: desktop ? 0.985 : 0.965,
                    child: ProfileCard(
                      profile: next,
                      isPro: state.isPro,
                      photoIndex: 0,
                      dimmed: true,
                    ),
                  ),

                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) {
                      if (_offset.distance > 8) return;
                      if (current.photos.length <= 1) return;

                      final x = d.localPosition.dx;
                      final half = size.width / 2;
                      if (x < half) {
                        _photoPrev(current);
                      } else {
                        _photoNext(current);
                      }
                    },
                    onPanUpdate: (d) {
                      if (_isAnimating) return;
                      _panUpdateThrottled(d, size);
                    },
                    onPanEnd: (d) async {
                      if (_isAnimating) return;

                      final isRight = _offset.dx > _swipeThreshold;
                      final isLeft = _offset.dx < -_swipeThreshold;
                      final isUp = _offset.dy < -_swipeThreshold;

                      if (isUp) {
                        await _doSuperLike(context, state);
                        return;
                      }

                      if (isRight) {
                        _doLike(context, state);
                        return;
                      }

                      if (isLeft) {
                        _doNope(context, state);
                        return;
                      }

                      _animateTo(Offset.zero, 0, () {
                        _isAnimating = false;
                        _controller.reset();
                        setState(() {
                          _offset = Offset.zero;
                          _angle = 0;
                        });
                      });
                    },
                    child: RepaintBoundary(
                      child: Transform.translate(
                        offset: _offset,
                        child: Transform.rotate(
                          angle: _angle,
                          child: Stack(
                            children: [
                              ProfileCard(
                                profile: current,
                                isPro: state.isPro,
                                photoIndex: photoIdx,
                                dimmed: false,
                              ),
                              SwipeStamp(offset: _offset),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiscoverSidePanel extends StatelessWidget {
  final bool isPro;
  final int likesUsed;
  final int likeLimit;

  final VoidCallback onUpgrade;
  final VoidCallback onRewind;
  final VoidCallback onNope;
  final VoidCallback onSuper;
  final VoidCallback onLike;

  const _DiscoverSidePanel({
    required this.isPro,
    required this.likesUsed,
    required this.likeLimit,
    required this.onUpgrade,
    required this.onRewind,
    required this.onNope,
    required this.onSuper,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Actions",
                      style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    if (!isPro)
                      TextButton(
                        onPressed: onUpgrade,
                        child: const Text("Upgrade"),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(.12)),
                        ),
                        child: Text(
                          "PRO",
                          style: TextStyle(color: Colors.white.withOpacity(.95), fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isPro ? "Unlimited Likes" : "Likes: $likesUsed/$likeLimit",
                  style: TextStyle(color: Colors.white.withOpacity(.7)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onNope,
                        icon: const Icon(Icons.close),
                        label: const Text("Nope"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(.85),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onLike,
                        icon: const Icon(Icons.favorite),
                        label: const Text("Like"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(.85),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSuper,
                        icon: const Icon(Icons.star),
                        label: const Text("Super"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(.25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRewind,
                        icon: const Icon(Icons.undo),
                        label: const Text("Rewind"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isPro ? Colors.amberAccent : Colors.white.withOpacity(.45),
                          side: BorderSide(color: Colors.white.withOpacity(.25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.white.withOpacity(.65)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Desktop Tipp: Nutze A/D/W/Z und ←/→ für Fotos. Das fühlt sich wie echte Web-App an.",
                      style: TextStyle(color: Colors.white.withOpacity(.65), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTopBar extends StatelessWidget {
  final bool isPro;
  final VoidCallback onTapPro;
  final VoidCallback onTapFilters;

  const _DiscoverTopBar({
    required this.isPro,
    required this.onTapPro,
    required this.onTapFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: Colors.white.withOpacity(.92)),
          const SizedBox(width: 8),
          Text(
            "Dating",
            style: TextStyle(
              color: Colors.white.withOpacity(.95),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTapPro,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPro ? Colors.pinkAccent.withOpacity(.25) : Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? Icons.workspace_premium : Icons.lock_open,
                    size: 16,
                    color: Colors.white.withOpacity(.92),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPro ? "PRO" : "Upgrade",
                    style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onTapFilters,
            icon: Icon(Icons.tune, color: Colors.white.withOpacity(.9)),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(.35),
            )
          ],
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

/// =======================
/// PROFILE CARD (image perf)
/// =======================
class ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isPro;
  final int photoIndex;
  final bool dimmed;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.isPro,
    required this.photoIndex,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final overlayOpacity = dimmed ? 0.25 : 0.0;

    final safePhotoIndex = photoIndex.clamp(0, max(0, profile.photos.length - 1)).toInt();
    final photoUrl = profile.photos.isEmpty ? "" : profile.photos[safePhotoIndex];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // On web, huge shadows can be expensive. Keep it but not insane.
          BoxShadow(
            blurRadius: kIsWeb ? 28 : 44,
            offset: const Offset(0, 18),
            color: Colors.black.withOpacity(.55),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final dpr = MediaQuery.of(ctx).devicePixelRatio;
              final targetW = (c.maxWidth * dpr).round();
              final targetH = (c.maxHeight * dpr).round();

              // Limit cache size on web (big win)
              final cacheW = kIsWeb ? min(targetW, 1000) : targetW;
              final cacheH = kIsWeb ? min(targetH, 1400) : targetH;

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (photoUrl.isNotEmpty)
                    Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      cacheWidth: cacheW,
                      cacheHeight: cacheH,
                      filterQuality: kIsWeb ? FilterQuality.low : FilterQuality.medium,
                      gaplessPlayback: true,
                      // prevents "jump" while loading
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _fallback(),
                            Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(.8)),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  else
                    _fallback(),
                  if (overlayOpacity > 0) Container(color: Colors.black.withOpacity(overlayOpacity)),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: _PhotoProgressBar(total: max(1, profile.photos.length), active: safePhotoIndex),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 92, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(.55),
                            Colors.black.withOpacity(.88),
                          ],
                        ),
                      ),
                      child: _CardInfo(profile: profile, isPro: isPro),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF0F0F0F)],
        ),
      ),
      child: Center(
        child: Text(
          "${profile.name}, ${profile.age}",
          style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 22),
        ),
      ),
    );
  }
}

class _PhotoProgressBar extends StatelessWidget {
  final int total;
  final int active;

  const _PhotoProgressBar({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i == active;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(.92) : Colors.white.withOpacity(.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _CardInfo extends StatelessWidget {
  final Profile profile;
  final bool isPro;

  const _CardInfo({required this.profile, required this.isPro});

  @override
  Widget build(BuildContext context) {
    final distanceText = isPro ? "${profile.distanceKm} km" : "≈ ${_bucketKm(profile.distanceKm)} km";

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamilyFallback: ["Roboto", "Arial"]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  "${profile.name}, ${profile.age}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Badge(
                icon: Icons.place,
                text: distanceText,
                trailingLock: !isPro,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile.bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontSize: 14.5,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _Pill(text: "Online", icon: Icons.circle, iconSize: 10),
              const _Pill(text: "Verifiziert", icon: Icons.verified),
              if (isPro) const _Pill(text: "PRO", icon: Icons.workspace_premium),
              ...profile.tags.take(2).map((t) => _Pill(text: t, icon: Icons.tag)),
            ],
          ),
        ],
      ),
    );
  }

  int _bucketKm(int km) {
    if (km <= 2) return 2;
    if (km <= 5) return 5;
    if (km <= 10) return 10;
    if (km <= 20) return 20;
    return 50;
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool trailingLock;

  const _Badge({
    required this.icon,
    required this.text,
    required this.trailingLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(.9), size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(.95), fontWeight: FontWeight.w800),
          ),
          if (trailingLock) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock, size: 14, color: Colors.white.withOpacity(.7)),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final double iconSize;

  const _Pill({required this.text, required this.icon, this.iconSize = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.white.withOpacity(.9)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class SwipeStamp extends StatelessWidget {
  final Offset offset;
  const SwipeStamp({super.key, required this.offset});

  @override
  Widget build(BuildContext context) {
    const threshold = 120.0;

    String? label;
    Color? color;
    double opacity = 0;

    if (offset.dx > 0) {
      opacity = (offset.dx / (threshold * 1.2)).clamp(0.0, 1.0);
      if (offset.dx > 12) {
        label = "LIKE";
        color = Colors.greenAccent;
      }
    } else if (offset.dx < 0) {
      opacity = (-offset.dx / (threshold * 1.2)).clamp(0.0, 1.0);
      if (offset.dx < -12) {
        label = "NOPE";
        color = Colors.redAccent;
      }
    }

    if (offset.dy < -threshold * 0.7 && offset.dx.abs() < 70) {
      opacity = ((-offset.dy) / (threshold * 1.2)).clamp(0.0, 1.0);
      label = "SUPER";
      color = Colors.blueAccent;
    }

    if (label == null) return const SizedBox.shrink();

    return Positioned(
      top: 22,
      left: label == "NOPE" ? null : 22,
      right: label == "NOPE" ? 22 : null,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: label == "NOPE" ? -0.18 : 0.18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: color!.withOpacity(.95), width: 3),
              borderRadius: BorderRadius.circular(14),
              color: Colors.black.withOpacity(.25),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// CHATS
/// =======================
class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                "Chats",
                style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (state.isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                  ),
                  child: Text(
                    "PRO",
                    style: TextStyle(color: Colors.white.withOpacity(.95), fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.matches.isEmpty
              ? Center(
                  child: Text(
                    "Noch keine Matches.\nSwipe in Discover 👇",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: state.matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final m = state.matches[i];
                    final p = state.profileById(m.profileId);
                    final thread = state.chatsByMatchId[m.id];
                    final last = (thread != null && thread.messages.isNotEmpty) ? thread.messages.last : null;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatDetailPage(matchId: m.id)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(.10)),
                        ),
                        child: Row(
                          children: [
                            _Avatar(url: p.photos.isNotEmpty ? p.photos.first : null),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(width: 8),
                                      if (m.superLikeNote != null)
                                        Icon(Icons.star, color: Colors.blueAccent.withOpacity(.95), size: 16),
                                      const Spacer(),
                                      Text(
                                        _timeShort(m.createdAt),
                                        style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    last?.text ?? "Schreib was 😄",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(.75)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _timeShort(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        color: Colors.white.withOpacity(.08),
        child: url == null
            ? Icon(Icons.person, color: Colors.white.withOpacity(.7))
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: kIsWeb ? 128 : null,
                filterQuality: kIsWeb ? FilterQuality.low : FilterQuality.medium,
                errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white.withOpacity(.7)),
              ),
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final String matchId;
  const ChatDetailPage({super.key, required this.matchId});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final match = state.matches.firstWhere((m) => m.id == widget.matchId);
    final p = state.profileById(match.profileId);
    final thread = state.chatsByMatchId[widget.matchId]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B10),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            _Avatar(url: p.photos.isNotEmpty ? p.photos.first : null),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  state.isPro ? "Read receipts: ON" : "Read receipts: Pro 🔒",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.7)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (state.isPro)
            IconButton(
              tooltip: "Icebreaker",
              onPressed: () {
                final s = state.generateIcebreaker(p);
                c.text = s;
                c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
              },
              icon: const Icon(Icons.auto_awesome),
            )
          else
            IconButton(
              tooltip: "Icebreaker (Pro)",
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF0B0B10),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => PaywallSheet(state: state),
              ),
              icon: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(.6)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: thread.messages.length,
              itemBuilder: (_, i) {
                final msg = thread.messages[i];
                final isMe = msg.fromMe;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.pinkAccent.withOpacity(.20) : Colors.white.withOpacity(.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(color: Colors.white.withOpacity(.92), height: 1.25),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${msg.at.hour.toString().padLeft(2, '0')}:${msg.at.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Icon(
                                msg.seen ? Icons.done_all : Icons.done,
                                size: 14,
                                color: state.isPro ? Colors.greenAccent.withOpacity(.9) : Colors.white.withOpacity(.35),
                              ),
                            ],
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: c,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Nachricht…",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final text = c.text.trim();
                    if (text.isEmpty) return;
                    state.sendMessage(widget.matchId, text, proReadReceipt: state.isPro);
                    c.clear();
                  },
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// ACCOUNT + WHO LIKED YOU
/// =======================
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  void _showPaywall(BuildContext context) {
    final state = AppStateScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PaywallSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        Row(
          children: [
            Text(
              "Account",
              style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _showPaywall(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: state.isPro ? Colors.pinkAccent.withOpacity(.25) : Colors.white.withOpacity(.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(state.isPro ? Icons.workspace_premium : Icons.lock_open,
                        size: 16, color: Colors.white.withOpacity(.92)),
                    const SizedBox(width: 6),
                    Text(
                      state.isPro ? "PRO" : "Upgrade",
                      style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 52,
                  height: 52,
                  color: Colors.white.withOpacity(.08),
                  child: Icon(Icons.person, color: Colors.white.withOpacity(.8)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${state.me.name}, ${state.me.age}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.me.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(.75)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(title: "Subscription & Vorteile"),
        SwitchListTile.adaptive(
          value: state.isPro,
          onChanged: (v) => state.togglePro(v),
          title: const Text("Dating Pro (Demo)"),
          subtitle: Text(
            "Unlimited Likes • Rewind • Super Like Nachricht • Who liked you • Advanced Filters • Icebreakers",
            style: TextStyle(color: Colors.white.withOpacity(.65)),
          ),
        ),
        const SizedBox(height: 6),
        const _SectionTitle(title: "Pro Features"),
        SwitchListTile.adaptive(
          value: state.incognito,
          onChanged: (v) {
            if (!state.isPro) return _showPaywall(context);
            state.toggleIncognito(v);
          },
          title: const Text("Incognito Mode (Pro)"),
          subtitle: Text(
            "Du wirst nur Leuten angezeigt, die du likest (Demo-Logik).",
            style: TextStyle(color: Colors.white.withOpacity(.65)),
          ),
        ),
        SwitchListTile.adaptive(
          value: state.travelMode,
          onChanged: (v) {
            if (!state.isPro) return _showPaywall(context);
            state.toggleTravelMode(v);
          },
          title: const Text("Travel Mode (Pro)"),
          subtitle: Text("Swipe in anderer Stadt (Demo).", style: TextStyle(color: Colors.white.withOpacity(.65))),
        ),
        const SizedBox(height: 10),
        const _SectionTitle(title: "Advanced Filters (Pro)"),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Age range: ${state.minAge} – ${state.maxAge}",
                style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800),
              ),
              Slider(
                value: state.minAge.toDouble(),
                min: 18,
                max: 60,
                divisions: 42,
                onChanged: (v) {
                  if (!state.isPro) return;
                  state.updateFilters(minA: v.round());
                },
              ),
              Slider(
                value: state.maxAge.toDouble(),
                min: 18,
                max: 60,
                divisions: 42,
                onChanged: (v) {
                  if (!state.isPro) return;
                  state.updateFilters(maxA: v.round());
                },
              ),
              const SizedBox(height: 8),
              Text(
                "Max distance: ${state.maxDistanceKm} km",
                style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800),
              ),
              Slider(
                value: state.maxDistanceKm.toDouble(),
                min: 2,
                max: 100,
                divisions: 98,
                onChanged: (v) {
                  if (!state.isPro) return;
                  state.updateFilters(maxDist: v.round());
                },
              ),
              if (!state.isPro)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text("🔒 Pro nötig", style: TextStyle(color: Colors.white.withOpacity(.6))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(title: "Who liked you"),
        _WhoLikedYouCard(onUpgrade: () => _showPaywall(context)),
      ],
    );
  }
}

class _WhoLikedYouCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _WhoLikedYouCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final ids = state.whoLikedYou;
    final list = ids.map((id) => state.profileById(id)).where((p) => p.id.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.isPro ? "Diese Nutzer haben dich geliked:" : "Blurred in Free • Sichtbar in Pro",
            style: TextStyle(color: Colors.white.withOpacity(.85), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Text("Niemand gerade 😄", style: TextStyle(color: Colors.white.withOpacity(.7)))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: list.map((p) {
                final tile = _WhoTile(profile: p, blurred: !state.canSeeWhoLikedYou);
                return state.canSeeWhoLikedYou
                    ? tile
                    : InkWell(
                        onTap: onUpgrade,
                        child: tile,
                      );
              }).toList(),
            ),
          if (!state.canSeeWhoLikedYou) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onUpgrade,
              child: const Text("Upgrade um zu sehen"),
            )
          ],
        ],
      ),
    );
  }
}

class _WhoTile extends StatelessWidget {
  final Profile profile;
  final bool blurred;

  const _WhoTile({required this.profile, required this.blurred});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: [
          _Avatar(url: profile.photos.isNotEmpty ? profile.photos.first : null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${profile.name}, ${profile.age}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (!blurred) return child;

    // Web: no BackdropFilter (expensive). Mobile: blur ok.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: kIsWeb
                ? Container(color: Colors.black.withOpacity(.25))
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.black.withOpacity(.15)),
                  ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(.12)),
                ),
                child: const Text("PRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 14, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// =======================
/// PAYWALL + FILTERS SHEETS
/// =======================
class PaywallSheet extends StatelessWidget {
  final AppState state;
  const PaywallSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white),
              const SizedBox(width: 10),
              const Text(
                "Dating Pro",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.white.withOpacity(.9)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Nicht nur Swipe — sondern bessere Outcomes:",
            style: TextStyle(color: Colors.white.withOpacity(.85)),
          ),
          const SizedBox(height: 14),
          _benefit("Unbegrenzte Likes"),
          _benefit("5 Superlikes/Tag + Nachricht (Icebreaker)"),
          _benefit("Rewind (Undo)"),
          _benefit("Who liked you (ohne Blur)"),
          _benefit("Incognito + Advanced Filters"),
          _benefit("Icebreaker Generator im Chat"),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    state.togglePro(true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent.withOpacity(.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Upgrade (Demo aktivieren)"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.isPro)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      state.togglePro(false);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(.25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Pro deaktivieren (Demo)"),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            "Payment (Google/Apple) kommt später – hier ist nur Logik/UI.",
            style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class FiltersSheet extends StatelessWidget {
  const FiltersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Advanced Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.white.withOpacity(.9)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text("Age: ${state.minAge} – ${state.maxAge}", style: TextStyle(color: Colors.white.withOpacity(.9))),
          Slider(
            value: state.minAge.toDouble(),
            min: 18,
            max: 60,
            divisions: 42,
            onChanged: (v) => state.updateFilters(minA: v.round()),
          ),
          Slider(
            value: state.maxAge.toDouble(),
            min: 18,
            max: 60,
            divisions: 42,
            onChanged: (v) => state.updateFilters(maxA: v.round()),
          ),
          const SizedBox(height: 8),
          Text("Distance: ${state.maxDistanceKm} km", style: TextStyle(color: Colors.white.withOpacity(.9))),
          Slider(
            value: state.maxDistanceKm.toDouble(),
            min: 2,
            max: 100,
            divisions: 98,
            onChanged: (v) => state.updateFilters(maxDist: v.round()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }
}
