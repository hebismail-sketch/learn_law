import 'package:flutter/material.dart';
import '../../domain/entities/case_step_entity.dart';
import '../../domain/entities/step_branch.dart';

class StepDetailScreen extends StatefulWidget {
  final String caseName;
  final CaseStepEntity step;

  const StepDetailScreen({
    super.key,
    required this.caseName,
    required this.step,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  int _selectedBranchIndex = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final hasBranches = step.branches.isNotEmpty;

    // حماية من أي index خارج نطاق الفروع (يمنع RangeError وتوقف الشاشة).
    final safeBranchIndex =
        _selectedBranchIndex.clamp(0, step.branches.isEmpty ? 0 : step.branches.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'الخطوة ${step.stepNumber}: ${step.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Render step header card container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.caseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الخطوة رقم (${step.stepNumber})',
                    style: TextStyle(
                      color: Colors.blue.shade100,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Render operational procedures and description card
            _DetailSectionCard(
              title: 'الإجراءات العامة للمرحلة',
              icon: Icons.assignment_outlined,
              iconColor: Colors.blue,
              content: step.shortDescription.isNotEmpty
                  ? step.shortDescription
                  : 'تتضمن هذه المرحلة استيفاء الشروط القانونية ومتابعة الإجراءات المقررة نظاماً.',
            ),

            // Render Dynamic Branches section if present
            if (hasBranches) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'المسارات والسيناريوهات المتفرعة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.alt_route_rounded, color: Colors.amber.shade800, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              // Branch selector chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: List.generate(step.branches.length, (index) {
                    final branch = step.branches[index];
                    final isSelected = _selectedBranchIndex == index;

                    Color chipColor = const Color(0xFF1E3A8A);
                    if (branch.title.contains('قبول')) {
                      chipColor = Colors.green.shade700;
                    } else if (branch.title.contains('رفض')) {
                      chipColor = Colors.red.shade700;
                    } else if (branch.title.contains('استئناف') || branch.title.contains('طعن')) {
                      chipColor = Colors.amber.shade800;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          branch.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: chipColor,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedBranchIndex = index);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
              // Selected Branch Content card
              _buildBranchCard(step.branches[safeBranchIndex]),
            ],

            const SizedBox(height: 16),

            // Render lawyer tips and notes card
            const _DetailSectionCard(
              title: 'نصائح وملاحظات للمحامي',
              icon: Icons.lightbulb_outline_rounded,
              iconColor: Colors.amber,
              content:
              'تأكد من توقيع الموكل على كافة التوكيلات الرسمية والتحقق من صحة تواريخ المستندات وسلامتها قبل إيداع الصحيفة أمام قلم الكتاب.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard(StepBranch branch) {
    Color headerColor = const Color(0xFF1E3A8A);
    if (branch.title.contains('قبول')) {
      headerColor = Colors.green.shade700;
    } else if (branch.title.contains('رفض')) {
      headerColor = Colors.red.shade700;
    } else if (branch.title.contains('استئناف') || branch.title.contains('طعن')) {
      headerColor = Colors.amber.shade800;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headerColor.withOpacity(0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    branch.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: headerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تفاصيل وإجراءات المسار',
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.call_split_rounded, color: headerColor, size: 20),
            ],
          ),
          const Divider(height: 20),
          if (branch.description.isNotEmpty) ...[
            Text(
              branch.description,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.7,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (branch.subSteps.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المحطات والخطوات المتتالية لهذا المسار:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(branch.subSteps.length, (sIdx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: headerColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        branch.subSteps[sIdx],
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: headerColor.withOpacity(0.15),
                      child: Text(
                        '${sIdx + 1}',
                        style: TextStyle(color: headerColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else if (branch.description.isEmpty) ...[
            const Text(
              'لم يتم تحديد خطوات تفصيلية لهذا المسار.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String content;

  const _DetailSectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF334155),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}