import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/legal_case_entity.dart';
import '../../domain/entities/case_step_entity.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import 'step_detail_screen.dart';

class CaseRoadmapScreen extends StatelessWidget {
  final LegalCaseEntity legalCase;

  const CaseRoadmapScreen({
    super.key,
    required this.legalCase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          legalCase.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocBuilder<LegalCubit, LegalState>(
        builder: (context, state) {
          if (state is LegalLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CaseStepsLoaded) {
            final steps = state.caseSteps;
            if (steps.isEmpty) {
              return const Center(
                child: Text(
                  'لم تتم إضافة خطوات ومسار لهذه القضية بعد',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return Column(
              children: [
                // Display roadmap header summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${steps.length} خطوات للدعوى',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Text(
                        'خريطة طريق سير القضية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Build interactive roadmap step nodes list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final isLast = index == steps.length - 1;

                      return _RoadmapStepNode(
                        step: step,
                        isLast: isLast,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StepDetailScreen(
                                caseName: legalCase.name,
                                step: step,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          } else if (state is LegalError) {
            return Center(
              child: Text(
                'حدث خطأ: ${state.message}',
                style: const TextStyle(color: Colors.red, fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _RoadmapStepNode extends StatelessWidget {
  final CaseStepEntity step;
  final bool isLast;
  final VoidCallback onTap;

  const _RoadmapStepNode({
    required this.step,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Render interactive step card container
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                elevation: 3,
                shadowColor: Colors.black12,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.0),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.touch_app_rounded, size: 14, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    'التفاصيل والأوراق',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'المرحلة ${step.stepNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (step.shortDescription.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            step.shortDescription,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Render timeline indicator column and connecting line
          Column(
            children: [
              // Render numbered sequence node
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(75),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${step.stepNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // Render line connecting to next milestone node
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}