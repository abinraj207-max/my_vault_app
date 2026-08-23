// import 'package:flutter/material.dart';

// class AppColors {
//   // Main background (Deep Dark Teal/Green)
//   static const Color background = Color.fromARGB(255, 2, 75, 67);

//   // Highlight accent (Vibrant Lime Green)
//   static const Color highlight = Color(0xFFCAFF00);

//   // Surface / Container color (Slightly lighter teal)
//   static const Color surface = Color(0xFF004540);

//   // Secondary surface color (e.g. for card content or text fields)
//   static const Color surfaceVariant = Color(0xFF00544E);

//   // Subtle border color
//   static const Color border = Color(0xFF00615A);

//   // Text Colors
//   static const Color textPrimary = Colors.white;
//   static const Color textSecondary = Color(0xFF90B5B1);
//   static const Color textDisabled = Color(0xFF6B8784);
// }

// class AppTheme {
//   static ThemeData get themeData {
//     return ThemeData(
//       useMaterial3: true,
//       brightness: Brightness.dark,
//       scaffoldBackgroundColor: AppColors.background,
//       primaryColor: AppColors.highlight,
//       cardColor: AppColors.surface,
//       dividerColor: AppColors.border,

//       colorScheme: const ColorScheme.dark(
//         primary: AppColors.highlight,
//         secondary: AppColors.highlight,
//         background: AppColors.background,
//         surface: AppColors.surface,
//         surfaceVariant: AppColors.surfaceVariant,
//         onPrimary: Colors.black,
//         onSecondary: Colors.black,
//         onBackground: AppColors.textPrimary,
//         onSurface: AppColors.textPrimary,
//       ),

//       // Typography
//       textTheme: const TextTheme(
//         headlineLarge: TextStyle(
//           color: AppColors.textPrimary,
//           fontWeight: FontWeight.bold,
//         ),
//         headlineMedium: TextStyle(
//           color: AppColors.textPrimary,
//           fontWeight: FontWeight.bold,
//         ),
//         titleLarge: TextStyle(
//           color: AppColors.textPrimary,
//           fontWeight: FontWeight.bold,
//         ),
//         titleMedium: TextStyle(
//           color: AppColors.textPrimary,
//           fontWeight: FontWeight.w600,
//         ),
//         titleSmall: TextStyle(
//           color: AppColors.textPrimary,
//           fontWeight: FontWeight.w600,
//         ),
//         bodyLarge: TextStyle(color: AppColors.textPrimary),
//         bodyMedium: TextStyle(color: AppColors.textSecondary),
//         bodySmall: TextStyle(color: AppColors.textDisabled),
//       ),

//       // AppBar Theme
//       appBarTheme: const AppBarTheme(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: IconThemeData(color: AppColors.highlight),
//         actionsIconTheme: IconThemeData(color: AppColors.highlight),
//         titleTextStyle: TextStyle(
//           color: AppColors.textPrimary,
//           fontSize: 20,
//           fontWeight: FontWeight.bold,
//         ),
//       ),

//       // Input Decoration (Text Fields)
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.surface,
//         labelStyle: const TextStyle(color: AppColors.textSecondary),
//         hintStyle: const TextStyle(color: AppColors.textDisabled),
//         prefixIconColor: AppColors.highlight,
//         suffixIconColor: AppColors.highlight,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.border, width: 1),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.border, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.highlight, width: 1.5),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
//         ),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 16,
//         ),
//       ),

//       // Buttons Theme
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.highlight,
//           foregroundColor: Colors.black,
//           elevation: 0,
//           padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//       ),

//       outlinedButtonTheme: OutlinedButtonThemeData(
//         style: OutlinedButton.styleFrom(
//           foregroundColor: AppColors.highlight,
//           side: const BorderSide(color: AppColors.highlight, width: 1.5),
//           padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//       ),

//       textButtonTheme: TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: AppColors.highlight,
//           textStyle: const TextStyle(fontWeight: FontWeight.bold),
//         ),
//       ),

//       // Card Theme
//       cardTheme: CardThemeData(
//         color: AppColors.surface,
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//           side: const BorderSide(color: AppColors.border, width: 1),
//         ),
//       ),

//       // Switch Theme (used for biometric switch, etc.)
//       switchTheme: SwitchThemeData(
//         thumbColor: MaterialStateProperty.resolveWith<Color?>((states) {
//           if (states.contains(MaterialState.selected)) {
//             return Colors.black;
//           }
//           return Colors.grey;
//         }),
//         trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
//           if (states.contains(MaterialState.selected)) {
//             return AppColors.highlight;
//           }
//           return AppColors.border;
//         }),
//       ),

//       // Floating Action Button Theme
//       floatingActionButtonTheme: const FloatingActionButtonThemeData(
//         backgroundColor: AppColors.highlight,
//         foregroundColor: Colors.black,
//         elevation: 2,
//         shape: CircleBorder(),
//       ),

//       // Dialog Theme
//       dialogTheme: DialogThemeData(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//           side: const BorderSide(color: AppColors.border, width: 1.5),
//         ),
//         titleTextStyle: const TextStyle(
//           color: AppColors.textPrimary,
//           fontSize: 20,
//           fontWeight: FontWeight.bold,
//         ),
//         contentTextStyle: const TextStyle(
//           color: AppColors.textSecondary,
//           fontSize: 14,
//         ),
//       ),

//       // Chip Theme
//       chipTheme: ChipThemeData(
//         backgroundColor: AppColors.surfaceVariant,
//         disabledColor: AppColors.surface,
//         selectedColor: AppColors.highlight,
//         secondarySelectedColor: AppColors.highlight,
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         labelStyle: const TextStyle(
//           color: Colors.white,
//           fontSize: 12,
//           fontWeight: FontWeight.w500,
//         ),
//         secondaryLabelStyle: const TextStyle(
//           color: Colors.black,
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//         ),
//         brightness: Brightness.dark,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//           side: const BorderSide(color: AppColors.border, width: 1),
//         ),
//       ),

//       // Bottom Sheet Theme
//       bottomSheetTheme: const BottomSheetThemeData(
//         backgroundColor: AppColors.background,
//         modalBackgroundColor: AppColors.background,
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//           side: BorderSide(color: AppColors.border, width: 1),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

class AppColors {
  // Main background (Deep Obsidian Navy)
  static const Color background = Color(0xFF070A13);

  // Highlight accent (Vibrant Cyber Cyan)
  static const Color highlight = Color.fromARGB(255, 107, 209, 12);

  // Surface / Container color (Slate Navy)
  static const Color surface = Color(0xFF0F1626);

  // Secondary surface color (Lighter Slate Navy)
  static const Color surfaceVariant = Color(0xFF17223B);

  // Subtle border color (Steel Blue)
  static const Color border = Color(0xFF1E2D4A);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8A99AD);
  static const Color textDisabled = Color(0xFF53637A);
}

class AppTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.highlight,
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.highlight,
        secondary: AppColors.highlight,
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceVariant: AppColors.surfaceVariant,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
      ),

      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        bodySmall: TextStyle(color: AppColors.textDisabled),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.highlight),
        actionsIconTheme: IconThemeData(color: AppColors.highlight),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Input Decoration (Text Fields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        prefixIconColor: AppColors.highlight,
        suffixIconColor: AppColors.highlight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.highlight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Buttons Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlight,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.highlight,
          side: const BorderSide(color: AppColors.highlight, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.highlight,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Switch Theme (used for biometric switch, etc.)
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.highlight;
          }
          return AppColors.border;
        }),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.highlight,
        foregroundColor: Colors.black,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        disabledColor: AppColors.surface,
        selectedColor: AppColors.highlight,
        secondarySelectedColor: AppColors.highlight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        modalBackgroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }
}
