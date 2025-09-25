import 'package:flutter/material.dart';

/// Common AppBar widget with consistent blue styling across the app
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const CommonAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: const Color(0xFF0d6efd),
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Common header section widget (like the Member Details section)
class CommonSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const CommonSectionHeader({
    Key? key,
    required this.title,
    required this.icon,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Blue header section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF0d6efd),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Content section
          child,
        ],
      ),
    );
  }
}
