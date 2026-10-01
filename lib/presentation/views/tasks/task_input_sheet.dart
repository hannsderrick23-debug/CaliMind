import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/task_provider.dart';

class TaskInputSheet extends ConsumerStatefulWidget {
  final Task? taskToEdit;

  const TaskInputSheet({super.key, this.taskToEdit});

  @override
  ConsumerState<TaskInputSheet> createState() => _TaskInputSheetState();
}

class _TaskInputSheetState extends ConsumerState<TaskInputSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskCategory _category = TaskCategory.personal;
  int _duration = 30;
  int _priority = 2;
  PreferredTime? _preferredTime;
  bool _isSaving = false;

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.taskToEdit!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description ?? '';
      _category = t.category;
      _duration = t.duration;
      _priority = t.priority;
      _preferredTime = t.preferredTime;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    await HapticFeedbackUtils.heavyImpact();

    if (_isEditing) {
      final updated = widget.taskToEdit!.copyWith(
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        duration: _duration,
        priority: _priority,
        preferredTime: _preferredTime,
      );
      await ref.read(taskProvider.notifier).updateTask(updated);
    } else {
      await ref.read(taskProvider.notifier).createTask(NewTask(
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        duration: _duration,
        priority: _priority,
        preferredTime: _preferredTime,
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: CaliMindColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: CaliMindColors.mindGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isEditing ? LucideIcons.pencil : LucideIcons.plus,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? 'Edit Task' : 'New Task',
                  style: CaliMindTypography.h3,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: CaliMindColors.mutedForeground, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Title
            _buildLabel('Title *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleCtrl,
              hint: 'What do you need to do?',
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),

            // Description
            _buildLabel('Description (optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descCtrl,
              hint: 'Add context or notes...',
              maxLines: 2,
            ),
            const SizedBox(height: 18),

            // Category
            _buildLabel('Category'),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 18),

            // Duration + Priority row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDurationControl()),
                const SizedBox(width: 16),
                Expanded(child: _buildPriorityControl()),
              ],
            ),
            const SizedBox(height: 18),

            // Preferred time
            _buildLabel('Preferred Time'),
            const SizedBox(height: 8),
            _buildPreferredTimeChips(),
            const SizedBox(height: 26),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: CaliMindColors.mindGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: CaliMindColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _isEditing ? 'Save Changes' : 'Add Task',
                          style: CaliMindTypography.bodyLarge.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        style: CaliMindTypography.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: CaliMindTypography.bodyMedium.copyWith(color: CaliMindColors.mutedForeground),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TaskCategory.values.map((cat) {
        final isSelected = _category == cat;
        return GestureDetector(
          onTap: () {
            HapticFeedbackUtils.selectionClick();
            setState(() => _category = cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? cat.color.withValues(alpha: 0.15) : CaliMindColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? cat.color : CaliMindColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, size: 12, color: isSelected ? cat.color : CaliMindColors.mutedForeground),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: isSelected ? cat.color : CaliMindColors.mutedForeground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Duration'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CaliMindColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CaliMindColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _duration = (_duration - 15).clamp(5, 480)),
                child: const Icon(LucideIcons.minus, size: 16, color: CaliMindColors.mutedForeground),
              ),
              Text(
                _formatDur(_duration),
                style: CaliMindTypography.timeMonospace.copyWith(fontSize: 14),
              ),
              GestureDetector(
                onTap: () => setState(() => _duration = (_duration + 15).clamp(5, 480)),
                child: const Icon(LucideIcons.plus, size: 16, color: CaliMindColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Priority'),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((p) {
            final isSelected = _priority == p;
            final (label, color) = switch (p) {
              1 => ('P1', CaliMindColors.destructive),
              2 => ('P2', CaliMindColors.warning),
              _ => ('P3', CaliMindColors.mutedForeground),
            };
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtils.selectionClick();
                  setState(() => _priority = p);
                },
                child: Container(
                  margin: EdgeInsets.only(right: p < 3 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : CaliMindColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : CaliMindColors.cardBorder,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: CaliMindTypography.bodySmall.copyWith(
                      color: isSelected ? color : CaliMindColors.mutedForeground,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreferredTimeChips() {
    return Wrap(
      spacing: 8,
      children: [
        _TimeChip(label: 'Any', isSelected: _preferredTime == null, onTap: () => setState(() => _preferredTime = null)),
        ...PreferredTime.values.map((pt) => _TimeChip(
              label: pt.label,
              isSelected: _preferredTime == pt,
              onTap: () => setState(() => _preferredTime = pt),
            )),
      ],
    );
  }

  String _formatDur(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CaliMindColors.primary.withValues(alpha: 0.15) : CaliMindColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? CaliMindColors.primary : CaliMindColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: CaliMindTypography.bodySmall.copyWith(
            color: isSelected ? CaliMindColors.primary : CaliMindColors.mutedForeground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
