import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart'; // 🌈 ton thème ReadOn

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nzbhmshkcwudzydeahrq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56Ymhtc2hrY3d1ZHp5ZGVhaHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NTk0NDksImV4cCI6MjA3NzEzNTQ0OX0.oE5vXlZjT89q13wpj1y_B_OwZ_rQd2VNKC0OgEuRGwM',
  );
  runApp(const ReadOnApp());
}

class ReadOnApp extends StatelessWidget {
  const ReadOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadOn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // ✅ ton thème personnalisé
      home: const WelcomePage(), // écran de choix entrée
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    FeedPage(),
    SessionsPage(),
    BibliothequePage(),
    StatsPage(),
    ProfilPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Bibliothèque',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// === Pages ===

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 72,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'ReadOn',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    'Déjà un compte ? Se connecter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: const Text(
                    'Pas encore de compte ? Créer un compte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    Future<void> sendResetPassword() async {
      final email = emailController.text.trim();
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entre ton email pour réinitialiser')),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        await supabase.auth.resetPasswordForEmail(
          email,
          redirectTo:
              'https://nzbhmshkcwudzydeahrq.supabase.co/auth/v1/callback',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email envoyé. Vérifie ta boîte de réception.'),
          ),
        );
      } on AuthException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’envoyer l’email de réinitialisation'),
          ),
        );
      }
    }

    Future<void> goToApp() async {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email et mot de passe requis')),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.session == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Connexion impossible')));
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } on AuthException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BackHeader(title: 'Se connecter'),
              const SizedBox(height: AppSpace.l),
              Text(
                'Bienvenue sur ReadOn',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Connecte-toi pour continuer',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xl),
              Text('Email', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  hintText: 'ton.email@mail.com',
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'Mot de passe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '••••••••'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: sendResetPassword,
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: goToApp,
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    Future<void> goToApp() async {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email et mot de passe requis')),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo:
              'https://nzbhmshkcwudzydeahrq.supabase.co/auth/v1/callback',
          data: {'display_name': name},
        );

        // Si la confirmation email est requise, aucune session ne sera active.
        final user = res.user;

        if (user != null && res.session != null) {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'email': email,
            'display_name': name,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte créé. Vérifie tes emails pour confirmer puis connecte-toi.',
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ConfirmEmailPage()),
        );
      } on AuthException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Créer un compte'),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Rejoins ReadOn',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Entre tes informations pour commencer à lire',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xl),
              Text('Nom', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Ton nom'),
              ),
              const SizedBox(height: AppSpace.m),
              Text('Email', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  hintText: 'ton.email@mail.com',
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'Mot de passe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '••••••••'),
              ),
              const SizedBox(height: AppSpace.l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: goToApp,
                  child: const Text(
                    'Créer un compte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    'Déjà un compte ? Se connecter',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfirmEmailPage extends StatelessWidget {
  const ConfirmEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BackHeader(title: 'Confirmation', titleColor: AppColors.primary),
              const SizedBox(height: AppSpace.xl),
              const Icon(
                Icons.mark_email_unread,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'Confirme ton compte',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Nous t’avons envoyé un email de confirmation.\nClique sur le lien pour activer ton compte.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'Une fois confirmé, reviens ici et connecte-toi.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    'J’ai confirmé mon email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String term) async {
    final query = term.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

    try {
      final data =
          await supabase
                  .from('profiles')
                  .select('id, display_name, email')
                  .or('display_name.ilike.$pattern,email.ilike.$pattern')
                  .limit(20)
              as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la recherche')),
      );
    }
  }

  Future<void> _addFriend(Map<String, dynamic> user) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetId = user['id'] as String?;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter un ami')),
      );
      return;
    }
    if (targetId == null || targetId == currentUser.id) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utilisateur invalide')));
      return;
    }

    final client = Supabase.instance.client;
    try {
      final existing = await client
          .from('friends')
          .select('id, status')
          .or(
            'and(requester_id.eq.${currentUser.id},addressee_id.eq.$targetId),and(requester_id.eq.$targetId,addressee_id.eq.${currentUser.id})',
          )
          .limit(1);

      if ((existing as List).isNotEmpty) {
        final status =
            (existing.first as Map)['status'] as String? ?? 'en attente';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Relation déjà $status')));
        return;
      }

      await client.from('friends').insert({
        'requester_id': currentUser.id,
        'addressee_id': targetId,
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation envoyée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter cet ami')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Rechercher des amis'),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Nom ou email',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: _results.isEmpty && !_loading
                    ? Center(
                        child: Text(
                          'Tape au moins 2 caractères pour chercher',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpace.s),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final name =
                              (user['display_name'] ?? user['email'])
                                  as String? ??
                              '';
                          final email = user['email'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.all(AppSpace.m),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(AppRadius.l),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.accentLight,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: AppSpace.xs),
                                      Text(
                                        email,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _addFriend(user),
                                  child: const Text(
                                    'Ajouter',
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();
  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchBooks(value);
    });
  }

  Future<void> _searchBooks(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'search_books',
        body: {'q': q},
      );

      List<dynamic> parsedResults = [];
      final payload = response.data;

      if (payload is Map<String, dynamic>) {
        final results = payload['results'];
        if (results is List) {
          parsedResults = results;
        }
      } else if (payload is List) {
        parsedResults = payload;
      } else if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final results = decoded['results'];
            if (results is List) parsedResults = results;
          } else if (decoded is List) {
            parsedResults = decoded;
          }
        } catch (_) {
          parsedResults = [];
        }
      }

      setState(() {
        _searchResults = parsedResults
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de recherche Google Books')),
      );
    }
  }

  Future<void> _addBookFromSearch(Map<String, dynamic> book) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Non connecté')));
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final title = (book['title'] as String?)?.trim();
      final author = (book['author'] as String?)?.trim();

      int? bookId;
      if (title != null && title.isNotEmpty) {
        try {
          var query = supabase.from('books').select('id').eq('title', title);
          if (author != null && author.isNotEmpty) {
            query = query.eq('author', author);
          }
          final existing = await query.maybeSingle();
          if (existing != null) {
            bookId = (existing['id'] as num?)?.toInt();
          }
        } catch (_) {
          bookId = null;
        }
      }

      if (bookId == null) {
        final insertPayload = {
          'title': title ?? 'Titre inconnu',
          'author': author,
          'cover_url': book['cover_url'],
          'description': book['description'],
        }..removeWhere((key, value) => value == null);

        final inserted = await supabase
            .from('books')
            .insert(insertPayload)
            .select('id')
            .single();
        bookId = (inserted['id'] as num).toInt();
      }

      await supabase.from('user_books').insert({
        'user_id': user.id,
        'book_id': bookId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book['title'] ?? 'Livre'} ajouté')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is PostgrestException ? e.message : e.toString();
      debugPrint('Add book from search failed: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ajouter ce livre : $message')),
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final pages = int.tryParse(_pagesController.text.trim());
    if (title.isEmpty || author.isEmpty || pages == null || pages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre, auteur et pages requis')),
      );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Non connecté')));
      return;
    }
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final inserted = await supabase
          .from('books')
          .insert({'title': title, 'author': author, 'total_pages': pages})
          .select('id')
          .single();

      final bookId = (inserted['id'] as num).toInt();
      await supabase.from('user_books').insert({
        'user_id': user.id,
        'book_id': bookId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Livre ajouté')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is PostgrestException ? e.message : e.toString();
      debugPrint('Manual book insert failed: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’ajout : $message')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Ajouter un livre'),
              const SizedBox(height: AppSpace.l),
              Text(
                'Recherche Google Books',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Titre, auteur ou ISBN',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (_searching) const LinearProgressIndicator(),
              const SizedBox(height: AppSpace.s),
              if (_searchResults.isNotEmpty)
                ..._searchResults.map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: ListTile(
                      leading: (book['cover_url'] as String?) != null
                          ? Image.network(
                              book['cover_url'] as String,
                              width: 40,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.menu_book_outlined),
                      title: Text(book['title'] ?? 'Sans titre'),
                      subtitle: Text(book['author'] ?? ''),
                      trailing: TextButton(
                        onPressed: () => _addBookFromSearch(book),
                        child: const Text(
                          'Ajouter',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Ajout manuel',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xl),
              Text('Titre', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Ex : Sapiens'),
              ),
              const SizedBox(height: AppSpace.m),
              Text('Auteur', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: _authorController,
                decoration: const InputDecoration(
                  hintText: 'Ex : Yuval Noah Harari',
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'Nombre de pages',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: _pagesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Ex : 412'),
              ),
              const SizedBox(height: AppSpace.l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with SingleTickerProviderStateMixin {
  static const goalProgress = 0.65;

  late final AnimationController _fabController;
  bool _isFabOpen = false;

  final List<FriendActivity> _activities = const [
    FriendActivity(
      name: 'Marie',
      detail: 'a lu 45 pages de "Sapiens"',
      progress: 0.32,
      emoji: '👏',
      avatarColor: AppColors.accentLight,
    ),
    FriendActivity(
      name: 'Paul',
      detail: 'a terminé "Les Misérables"',
      progress: 1,
      emoji: '🎉',
      avatarColor: Color(0xFFD8F5FF),
    ),
    FriendActivity(
      name: 'Tu as lu 124 pages cette semaine 🔥',
      detail: '65% de ton objectif',
      progress: goalProgress,
      emoji: '🔥',
      avatarColor: Color(0xFFF0FDF4),
      highlight: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      upperBound: 0.125, // 45 degrees
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SizedBox(
        width: 200,
        height: 220,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              right: 0,
              bottom: _isFabOpen ? 160 : 90,
              child: IgnorePointer(
                ignoring: !_isFabOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isFabOpen ? 1 : 0,
                  child: _ActionChip(
                    icon: Icons.play_arrow,
                    label: 'Commencer',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StartReadingPage(),
                        ),
                      );
                      _toggleFab();
                    },
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              right: 0,
              bottom: _isFabOpen ? 105 : 90,
              child: IgnorePointer(
                ignoring: !_isFabOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isFabOpen ? 1 : 0,
                  child: _ActionChip(
                    icon: Icons.add,
                    label: 'Ajouter livre',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddBookPage()),
                      );
                      _toggleFab();
                    },
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF35C0A7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3344E3B4),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _toggleFab,
                child: AnimatedBuilder(
                  animation: _fabController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _fabController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.add,
                    color: AppColors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _FeedHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.l,
                  vertical: AppSpace.l,
                ),
                children: [
                  const _ProgressCard(
                    title: 'Tu as lu 124 pages cette semaine 🔥',
                    subtitle: '65% de ton objectif',
                    progress: goalProgress,
                  ),
                  const SizedBox(height: AppSpace.m),
                  ..._activities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.m),
                      child: _FriendActivityCard(activity: activity),
                    ),
                  ),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl + AppSpace.s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.s,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfilPage(showBack: true),
                      ),
                    );
                  },
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.white,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchUsersPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.search,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            Text(
              'Accueil',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none,
                color: AppColors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;

  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpace.m),
          _ProgressBar(value: progress),
          const SizedBox(height: AppSpace.s),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FriendActivityCard extends StatelessWidget {
  final FriendActivity activity;

  const _FriendActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.border),
        boxShadow: activity.highlight
            ? const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 20, backgroundColor: activity.avatarColor),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          activity.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      activity.detail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          _ProgressBar(value: activity.progress),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: AppColors.accentLight.withOpacity(0.6),
        color: AppColors.primary,
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.l,
            vertical: AppSpace.s,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: AppSpace.s),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StartReadingPage extends StatelessWidget {
  const StartReadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Démarrer une lecture'),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Livre sélectionné',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 65,
                      height: 95,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sapiens',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Yuval Noah Harari',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpace.m),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.s,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.m,
                              ),
                            ),
                            onPressed: () {},
                            child: const Text('Changer de livre'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'Progression actuelle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgressBar(value: 0.3),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      children: [
                        Text(
                          '124 / 412 pages',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Dernière session : hier, 42 pages',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpace.xl,
                  horizontal: AppSpace.xl,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.l),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: AppColors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: AppSpace.m),
                    Text(
                      'Démarrer la lecture',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: AppSpace.s),
                  Text(
                    'Mode chronométré',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  const Icon(
                    Icons.menu_book,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpace.s),
                  Text(
                    'Ajouter les pages manuellement',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.l),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temps aujourd’hui : 45 min',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        Text(
                          'Pages cette semaine : 124',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text('🔥  '),
                            Text(
                              'Série : 6 jours',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendActivity {
  final String name;
  final String detail;
  final double progress;
  final String emoji;
  final Color avatarColor;
  final bool highlight;

  const FriendActivity({
    required this.name,
    required this.detail,
    required this.progress,
    required this.emoji,
    required this.avatarColor,
    this.highlight = false,
  });
}

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Sessions'));
  }
}

class BibliothequePage extends StatelessWidget {
  const BibliothequePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Bibliothèque'));
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Stats'));
  }
}

class ProfilPage extends StatelessWidget {
  final bool showBack;
  const ProfilPage({super.key, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  showBack
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      : const SizedBox(width: 48),
                  Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          color: AppColors.accentLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s),
                      Text(
                        'Adrien C.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Lecteur motivé depuis 2025',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.l),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiques',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      children: [
                        const Text('📚 12 Livres terminés'),
                        const SizedBox(width: AppSpace.m),
                        const Text('⏱️ 48 Heures'),
                        const SizedBox(width: AppSpace.m),
                        const Text('🔥 6 J'),
                      ],
                    ),
                    const SizedBox(height: AppSpace.m),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            right: index == 4 ? 0 : AppSpace.s,
                          ),
                          child: Container(
                            width: 12 + (index % 2 == 0 ? 4 : 0),
                            height: 28 + (index % 2 == 0 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.s),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsPage()),
                    );
                  },
                  child: const Text(
                    'Mes amis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UserBooksPage()),
                    );
                  },
                  child: const Text(
                    'Ma bibliothèque',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                'Ton objectif 2025',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '340 / 500 pages',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpace.s),
                          _ProgressBar(value: 0.68),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'Mes badges',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: AppSpace.s),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _Badge(color: AppColors.primary, label: '🌱 Débutant'),
                        _Badge(color: Color(0xFF6A5AE0), label: '🔥 Série 7j'),
                        _Badge(
                          color: AppColors.accentLight,
                          label: '📘 1er livre',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Voir tout →',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Partager mon profil',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text(
                    'Synchroniser mon compte Kindle',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _showKindleSyncDialog(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKindleSyncDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool syncing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpace.l,
            right: AppSpace.l,
            top: AppSpace.l,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpace.l,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              Future<void> submit() async {
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email et mot de passe Kindle requis'),
                    ),
                  );
                  return;
                }
                setSheetState(() => syncing = true);
                try {
                  await Supabase.instance.client.functions.invoke(
                    'sync_kindle',
                    body: {'email': email, 'password': password},
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Synchronisation Kindle lancée'),
                    ),
                  );
                } catch (e) {
                  final message = e.toString();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Impossible de synchroniser Kindle : $message',
                      ),
                    ),
                  );
                } finally {
                  if (ctx.mounted) {
                    setSheetState(() => syncing = false);
                  }
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connexion Kindle',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 20),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Amazon',
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe Amazon',
                    ),
                  ),
                  const SizedBox(height: AppSpace.l),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        syncing
                            ? 'Connexion en cours...'
                            : 'Se connecter à Kindle',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.m,
                        ),
                      ),
                      onPressed: syncing ? null : submit,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final String label;

  const _Badge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _friends = [];
  final Map<String, Map<String, dynamic>> _friendRelations = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Non connecté';
        _loading = false;
      });
      return;
    }
    try {
      final relations = await client
          .from('friends')
          .select('id, requester_id, addressee_id, status')
          .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
          .eq('status', 'accepted');

      final ids = <String>{};
      for (final rel in relations as List) {
        final map = rel as Map;
        final requester = map['requester_id'] as String?;
        final addressee = map['addressee_id'] as String?;
        if (requester != null &&
            addressee != null &&
            (requester == user.id || addressee == user.id)) {
          _friendRelations[requester == user.id ? addressee : requester] = map
              .map((key, value) => MapEntry(key.toString(), value));
          ids.add(requester == user.id ? addressee : requester);
        }
      }

      if (ids.isEmpty) {
        setState(() {
          _friends = [];
          _loading = false;
        });
        return;
      }

      final profiles = await client
          .from('profiles')
          .select('id, display_name, email')
          .inFilter('id', ids.toList());

      setState(() {
        _friends = (profiles as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement';
        _loading = false;
      });
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('friends')
          .delete()
          .or(
            'and(requester_id.eq.${user.id},addressee_id.eq.$friendId),and(requester_id.eq.$friendId,addressee_id.eq.${user.id})',
          );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ami supprimé')));
      _friendRelations.remove(friendId);
      await _loadFriends();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Suppression impossible')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Mes amis'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FriendRequestsPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.mail_outline,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Voir les demandes',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null && !_loading) Center(child: Text(_error!)),
              if (!_loading && _friends.isEmpty && _error == null)
                Center(
                  child: Text(
                    'Aucun ami pour le moment',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (!_loading && _friends.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _friends.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.s),
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      final name =
                          friend['display_name'] as String? ?? 'Aucun nom';
                      final email = friend['email'] as String? ?? '';
                      return Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.accentLight,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    email,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () =>
                                  _removeFriend(friend['id'] as String? ?? ''),
                              tooltip: 'Supprimer',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _userBooks = [];
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Non connecté';
        _loading = false;
      });
      return;
    }

    try {
      final data = await client
          .from('user_books')
          .select(
            'id, created_at, book:books(id, title, author, cover_url, description)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _userBooks = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement';
        _loading = false;
      });
    }
  }

  Future<void> _removeUserBook(String userBookId) async {
    if (userBookId.isEmpty) return;
    final client = Supabase.instance.client;
    setState(() {
      _deleting.add(userBookId);
    });
    try {
      await client.from('user_books').delete().eq('id', userBookId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Livre retiré')));
      await _loadBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer ce livre')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting.remove(userBookId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Ma bibliothèque'),
              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null && !_loading) Center(child: Text(_error!)),
              if (!_loading && _userBooks.isEmpty && _error == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Aucun livre dans ta bibliothèque',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              if (!_loading && _userBooks.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _userBooks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.s),
                    itemBuilder: (context, index) {
                      final entry = _userBooks[index];
                      final book = (entry['book'] as Map?) ?? {};
                      final title = book['title'] as String? ?? 'Sans titre';
                      final author =
                          book['author'] as String? ?? 'Auteur inconnu';
                      final cover = book['cover_url'] as String?;
                      final userBookId = entry['id']?.toString() ?? '';
                      final deleting = _deleting.contains(userBookId);

                      return Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.m,
                                ),
                                image: cover != null
                                    ? DecorationImage(
                                        image: NetworkImage(cover),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: cover == null
                                  ? const Icon(Icons.menu_book_outlined)
                                  : null,
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    author,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: deleting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.error,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                    ),
                              onPressed: deleting || userBookId.isEmpty
                                  ? null
                                  : () => _removeUserBook(userBookId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Non connecté';
        _loading = false;
      });
      return;
    }

    try {
      final relations = await client
          .from('friends')
          .select('id, requester_id, status')
          .eq('addressee_id', user.id)
          .eq('status', 'pending');

      final relationList = (relations as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (relationList.isEmpty) {
        setState(() {
          _requests = [];
          _loading = false;
          _error = null;
        });
        return;
      }

      final requesterIds = relationList
          .map((e) => e['requester_id'])
          .whereType<String>()
          .toList();

      final profiles = await client
          .from('profiles')
          .select('id, display_name, email')
          .inFilter('id', requesterIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles as List) {
        final map = Map<String, dynamic>.from(profile as Map);
        final id = map['id'] as String?;
        if (id != null) {
          profileMap[id] = map;
        }
      }

      final requests = relationList
          .map((rel) {
            final requesterId = rel['requester_id'] as String?;
            final profile = requesterId != null
                ? profileMap[requesterId]
                : null;
            return {
              'request_id': rel['id'],
              'requester_id': requesterId,
              'display_name': profile?['display_name'] ?? 'Utilisateur',
              'email': profile?['email'] ?? '',
            };
          })
          .where((req) => req['requester_id'] != null)
          .toList();

      if (!mounted) return;
      setState(() {
        _requests = requests.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement';
        _loading = false;
      });
    }
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    final client = Supabase.instance.client;
    setState(() {
      _processing.add(requestId);
    });
    try {
      if (accept) {
        await client
            .from('friends')
            .update({'status': 'accepted'})
            .eq('id', requestId);
      } else {
        await client.from('friends').delete().eq('id', requestId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Demande acceptée' : 'Demande refusée'),
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Action impossible')));
    } finally {
      if (mounted) {
        setState(() {
          _processing.remove(requestId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Demandes d\'amis'),
              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null && !_loading) Center(child: Text(_error!)),
              if (!_loading && _requests.isEmpty && _error == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Aucune demande en attente',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              if (!_loading && _requests.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.s),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      final name =
                          request['display_name'] as String? ?? 'Utilisateur';
                      final email = request['email'] as String? ?? '';
                      final requestId = request['request_id'] as String;
                      final busy = _processing.contains(requestId);
                      return Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.accentLight,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    email,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _respondToRequest(
                                            requestId,
                                            true,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.white,
                                      minimumSize: const Size.fromHeight(36),
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text('Accepter'),
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _respondToRequest(
                                            requestId,
                                            false,
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      minimumSize: const Size.fromHeight(34),
                                    ),
                                    child: const Text('Refuser'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(title: 'Paramètres', titleColor: AppColors.primary),
              const SizedBox(height: AppSpace.l),
              _SettingsSection(
                title: 'Profil',
                items: const [
                  _SettingsItem(label: '✏️ Modifier le nom'),
                  _SettingsItem(label: '📸 Changer la photo de profil'),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsSection(
                title: 'Lecture',
                items: const [
                  _SettingsItem(label: '🎯 Modifier l\'objectif de lecture'),
                  _SettingsItem(label: '🔔 Notifications de progression'),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsSection(
                title: 'Apparence',
                items: const [
                  _SettingsItem(label: '🌞 Thème clair (actif)'),
                  _SettingsItem(label: '🌙 Thème sombre'),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsSection(
                title: 'Compte',
                items: const [
                  _SettingsItem(label: '🖥️ Gérer connexions & appareils'),
                ],
              ),
              const SizedBox(height: AppSpace.l),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        title: const Text('Se déconnecter ?'),
                        content: const Text(
                          'Tu vas être déconnecté. Continuer ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // Retour à la page de connexion
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomePage()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    '❌ Se déconnecter',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpace.s),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(
                      bottom: e == items.last ? 0 : AppSpace.s,
                    ),
                    child: e,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String label;

  const _SettingsItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _BackHeader extends StatelessWidget {
  final String title;
  final Color? titleColor;

  const _BackHeader({required this.title, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: titleColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}
