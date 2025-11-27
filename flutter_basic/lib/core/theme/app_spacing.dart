import 'package:flutter/material.dart';
import 'package:flutter_basic/core/theme/app_colors.dart';

class AppSpacing {
	AppSpacing._();

	static const double xs = 4.0;
	static const double sm = 8.0;
	static const double md = 16.0;
	static const double lg = 24.0;
	static const double xl = 32.0;

	static const EdgeInsets screenPadding = EdgeInsets.symmetric(
		horizontal: md,
		vertical: sm,
	);
}

class AppDecorations {
	AppDecorations._();

	static BoxDecoration card = BoxDecoration(
		color: AppColors.surface,
		borderRadius: BorderRadius.circular(12),
		boxShadow: const [
			BoxShadow(
				color: Colors.black12,
				blurRadius: 6,
				offset: Offset(0, 2),
			),
		],
	);

	static OutlineInputBorder inputBorder = OutlineInputBorder(
		borderRadius: const BorderRadius.all(Radius.circular(8)),
		borderSide: BorderSide(color: AppColors.muted, width: 1),
	);
}

class AppInputs {
	AppInputs._();

	static InputDecoration filled({String? hint, Widget? prefix}) {
		return InputDecoration(
			hintText: hint,
			prefixIcon: prefix,
			filled: true,
			fillColor: AppColors.surface,
			contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
			border: AppDecorations.inputBorder,
			enabledBorder: AppDecorations.inputBorder,
			focusedBorder: AppDecorations.inputBorder.copyWith(
				borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
			),
		);
	}
}
