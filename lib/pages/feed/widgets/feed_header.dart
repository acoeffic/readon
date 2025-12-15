import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../profile/profile_page.dart';
import '../../friends/search_users_page.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

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
                        builder: (_) => ProfilePage(showBack: true),
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
                        builder: (_) => SearchUsersPage(),
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