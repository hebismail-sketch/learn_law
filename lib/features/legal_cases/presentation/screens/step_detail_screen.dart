import 'package:flutter/material.dart';
import '../../domain/entities/case_step_entity.dart';

class StepDetailScreen extends StatelessWidget {
  final String caseName;
  final CaseStepEntity step;

  const StepDetailScreen({
    super.key,
    required this.caseName,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'الخطوة ${step.stepNumber}: ${step.title}',
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
                      caseName,
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
              title: 'الإجراءات العملية والشرح',
              icon: Icons.assignment_outlined,
              iconColor: Colors.blue,
              content: step.shortDescription.isNotEmpty
                  ? step.shortDescription
                  : 'تتضمن هذه المرحلة بدء دراسة شروط الدعوى ومقابلة الموكل واستيفاء كافة الشروط القانونية المنصوص عليها قانوناً للبدء في الإجراءات القضائية.',
            ),

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