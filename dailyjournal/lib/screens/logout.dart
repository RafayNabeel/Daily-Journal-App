import 'package:dailyjournal/providers/userProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Import your user provider here
// import 'path/to/user_provider.dart';

// Logout Dialog Widget
class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.logout,
            color: Colors.red[600],
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Sign Out',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to sign out? You will need to sign in again to access your account.',
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return ElevatedButton(
              onPressed: userProvider.isLoading
                  ? null
                  : () async {
                      await userProvider.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home',
                          (route) => false,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: userProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

// Logout Button Widget
class LogoutButton extends StatelessWidget {
  final bool isIconOnly;
  final Color? color;
  final double? fontSize;

  const LogoutButton({
    super.key,
    this.isIconOnly = false,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Don't show logout button if user is not authenticated
        if (!userProvider.isAuthenticated && !userProvider.isGuest) {
          return const SizedBox.shrink();
        }

        if (isIconOnly) {
          return IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const LogoutDialog(),
              );
            },
            icon: Icon(
              Icons.logout,
              color: color ?? Colors.red[600],
            ),
            tooltip: 'Sign Out',
          );
        }

        return ListTile(
          leading: Icon(
            Icons.logout,
            color: color ?? Colors.red[600],
          ),
          title: Text(
            userProvider.isGuest ? 'Exit Guest Mode' : 'Sign Out',
            style: TextStyle(
              color: color ?? Colors.red[600],
              fontSize: fontSize ?? 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const LogoutDialog(),
            );
          },
        );
      },
    );
  }
}

// Settings Menu with Logout Option
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                // Navigate to profile
                Navigator.pushNamed(context, '/profile');
                break;
              case 'settings':
                // Navigate to settings
                Navigator.pushNamed(context, '/settings');
                break;
              case 'logout':
                showDialog(
                  context: context,
                  builder: (context) => const LogoutDialog(),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            if (userProvider.isAuthenticated) ...[
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
            ],
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Colors.red[600],
                ),
                title: Text(
                  userProvider.isGuest ? 'Exit Guest Mode' : 'Sign Out',
                  style: TextStyle(
                    color: Colors.red[600],
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }
}

// App Bar with User Info and Logout
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      actions: [
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            if (userProvider.currentUser != null) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: userProvider.currentUser!.profileImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              userProvider.currentUser!.profileImageUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  userProvider.currentUser!.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            userProvider.currentUser!.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Settings menu
                  const SettingsMenu(),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}