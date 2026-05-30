import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/matchmaking/presentation/providers/matchmaking_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

class SelectBackgroundScreen extends ConsumerStatefulWidget {
  final String? roomType;

  const SelectBackgroundScreen({super.key, this.roomType});

  @override
  ConsumerState<SelectBackgroundScreen> createState() =>
      _SelectBackgroundScreenState();
}

class _SelectBackgroundScreenState
    extends ConsumerState<SelectBackgroundScreen> {
  String? selectedLocation;

  final List<Map<String, String>> locations = [
    {
      'id': 'kao_tapu',
      'title': 'Kao Tapu',
      'image': 'assets/images/backgrounds/kao_tapu.png',
    },
    {
      'id': 'red_lotus_lake',
      'title': 'Red Lotus Lake',
      'image': 'assets/images/backgrounds/red_lotus_lake.png',
    },
    {
      'id': 'sea_of_cloud',
      'title': 'The Sea of Cloud',
      'image': 'assets/images/backgrounds/sea_of_cloud.png',
    },
    {
      'id': 'lumphini_park',
      'title': 'Lumphini Park',
      'image': 'assets/images/backgrounds/lumphini_park.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final roomType = widget.roomType ?? (args is String ? args : null);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.brownDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 90,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: 'Go back',
                      button: true,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: SvgPicture.asset(
                            'assets/images/icons/Back.svg',
                            width: 26,
                            height: 26,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Select room type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final loc = locations[index];
                final isSelected = selectedLocation == loc['id'];

                return GestureDetector(
                  onTap: () => setState(() => selectedLocation = loc['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        width: isSelected ? 4.5 : 1,
                        color: isSelected
                            ? const Color(0xFFF0BFD6)
                            : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isSelected ? 0.15 : 0.08,
                          ),
                          blurRadius: isSelected ? 14 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(isSelected ? 17 : 19),
                            ),
                            child: Image.asset(
                              loc['image']!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              loc['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: selectedLocation != null
                      ? () {
                          final selectedLocData = locations.firstWhere(
                            (loc) => loc['id'] == selectedLocation,
                          );
                          ref
                              .read(matchmakingNotifierProvider.notifier)
                              .setBackgroundTheme(selectedLocData['id']);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.findingRoom,
                            arguments: {
                              'roomName': selectedLocData['title'],
                              'bgImage': selectedLocData['image'],
                              'roomType': roomType,
                              'isGroup':
                                  roomType == 'group' || roomType == 'create',
                            },
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9EACF),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFE8E8E8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Let's go!",
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
