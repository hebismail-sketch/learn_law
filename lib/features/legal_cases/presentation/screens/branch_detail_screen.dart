import 'package:flutter/material.dart';

import '../../domain/entities/step_branch.dart';

class BranchDetailScreen extends StatelessWidget {
  final String caseName;
  final StepBranch branch;

  const BranchDetailScreen({
    super.key,
    required this.caseName,
    required this.branch,
  });

  Color get _accentColor {
    if (branch.outcome == 'acceptance' || branch.title.contains('قبول')) {
      return const Color(0xFF16A34A);
    }
    if (branch.outcome == 'rejection' || branch.title.contains('رفض')) {
      return const Color(0xFFDC2626);
    }
    if (branch.outcome == 'appeal' ||
        branch.title.contains('استئناف') ||
        branch.title.contains('طعن')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF4F46E5);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = branch.description.trim().isNotEmpty ||
        branch.subSteps.isNotEmpty ||
        branch.branches.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('تفاصيل المسار'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              if (branch.description.trim().isNotEmpty)
                _section(
                  title: 'وصف المسار',
                  icon: Icons.description_outlined,
                  child: Text(
                    branch.description,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              if (branch.subSteps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(
                  title: 'خصائص وإجراءات المسار',
                  icon: Icons.list_alt_rounded,
                  child: Column(
                    children: branch.subSteps
                        .asMap()
                        .entries
                        .map(
                          (entry) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _accentColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (branch.branches.isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(
                  title: 'مسارات فرعية',
                  icon: Icons.alt_route_rounded,
                  child: Column(
                    children: branch.branches
                        .map(
                          (child) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _accentColor,
                              size: 16,
                            ),
                            title: Text(
                              child.title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BranchDetailScreen(
                                  caseName: caseName,
                                  branch: child,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (!hasContent)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'لم تتم إضافة تفاصيل لهذا المسار بعد.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _accentColor.withOpacity(0.72)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            caseName,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            branch.title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(width: 8),
              Icon(icon, color: _accentColor),
            ],
          ),
          const Divider(height: 22),
          child,
        ],
      ),
    );
  }
}
