import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TakaSymbol extends StatelessWidget {
  final double size;
  final Color? color;

  const TakaSymbol({
    super.key,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg/Taka.svg',
      width: size,
      height: size,
      colorFilter: color != null 
          ? ColorFilter.mode(color!, BlendMode.srcIn) 
          : null,
    );
  }
}
