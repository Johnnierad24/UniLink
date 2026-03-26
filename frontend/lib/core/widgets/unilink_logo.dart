import 'package:flutter/material.dart';

class UniLinkLogo extends StatelessWidget {
  const UniLinkLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_option3.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.school, size: size, color: Theme.of(context).colorScheme.primary),
    );
  }
}
