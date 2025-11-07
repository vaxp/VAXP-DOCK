import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../cubit/system_stats_cubit.dart';
import 'stats_card.dart';

class SystemStatsGrid extends StatelessWidget {
  const SystemStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SystemStatsCubit, SystemStatsState>(
      builder: (context, state) {
        if (state is SystemStatsLoaded) {
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: 1,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 10,
            children: [
              StatsCard(
                title: AppStrings.cpu,
                value: '',
                unit: AppStrings.percentage,
                color: AppColors.cpuColor,
                icon: CupertinoIcons.settings,
                child: Text('% ${state.stats.cpuUsage.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatsCard(
                title: AppStrings.ram,
                value: '',
                unit: AppStrings.percentage,
                color: AppColors.ramColor,
                icon: Icons.memory,
                child: Text('% ${state.stats.memoryUsage.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatsCard(
                title: AppStrings.network,
                value: '',
                unit: AppStrings.networkPerSec,
                color: AppColors.networkColor,
                icon: CupertinoIcons.wifi,
                child: Text('${state.stats.networkDownload.toStringAsFixed(1)}/${state.stats.networkUpload.toStringAsFixed(1)} KB/s ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatsCard(
                title: AppStrings.disk,
                value: '',
                unit: AppStrings.megabytesPerSec,
                color: AppColors.diskColor,
                icon: CupertinoIcons.folder,
                child: Text('${state.stats.diskRead.toStringAsFixed(1)}/${state.stats.diskWrite.toStringAsFixed(1)} MB/s',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }
        return const Center(child: CupertinoActivityIndicator());
      },
    );
  }
}