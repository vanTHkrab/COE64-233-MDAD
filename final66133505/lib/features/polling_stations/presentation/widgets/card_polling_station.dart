import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/polling_station.dart';
import 'package:final66133505/core/theme/app_theme.dart';

class PollingStationCard extends StatelessWidget {
  final PollingStation station;
  final VoidCallback? onTap;

  const PollingStationCard({super.key, required this.station, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded, color: cs.onPrimaryContainer),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.stationName,
                      style: GoogleFonts.prompt(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${station.zone}, ${station.province}',
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                      const SizedBox(height: 4),
                       Icon(
                            station.isSynced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 15,
                            color: station.isSynced
                                ? AppTheme.syncedColor
                                : AppTheme.pendingColor,
                          ),
                    ],
                  )

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}