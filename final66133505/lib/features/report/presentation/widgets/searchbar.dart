import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportSearchBar extends StatelessWidget {
  const ReportSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.selectedSeverity,
    required this.onSeverityChanged,
  });

  final TextEditingController controller;
  final String searchQuery;
  final String? selectedSeverity;
  final ValueChanged<String?> onSeverityChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search by reporter or description',
              hintStyle: GoogleFonts.prompt(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.clear,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: selectedSeverity,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.filter_list_rounded),
            ),
            style: GoogleFonts.prompt(
              fontSize: 14,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('All severities', style: GoogleFonts.prompt()),
              ),
              ...['High', 'Medium', 'Low'].map(
                (s) => DropdownMenuItem<String?>(
                  value: s,
                  child: Text(s, style: GoogleFonts.prompt()),
                ),
              ),
            ],
            onChanged: onSeverityChanged,
          ),
        ],
      ),
    );
  }
}
