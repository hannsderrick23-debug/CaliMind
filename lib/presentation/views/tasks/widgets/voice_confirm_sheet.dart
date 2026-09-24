import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_feedback_utils.dart';
import '../../../domain/models/task.dart';
import '../../state/task_provider.dart';
import '../../state/voice_assistant_provider.dart';

class VoiceConfirmSheet extends ConsumerStatefulWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onDismissed;

  const VoiceConfirmSheet({
    super.key,
    required this.onConfirmed,
    required this.onDismissed,
  });

  @override
  ConsumerState<VoiceConfirmSheet> createState() => _VoiceConfirmSheetState();
}

class _VoiceConfirmSheetState extends ConsumerState<VoiceConfirmSheet> {
  late TextEditingController _titleCtrl;
  late NewTask _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(voiceAssistantProvider).draftTask!;
    _titleCtrl = TextEditingController(text: _draft.title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final updated = _draft.copyWith(title: _titleCtrl.text.trim());
    ref.read(voiceAssistantProvider.notifier).updateDraftTask(updated);

    final created = await ref.read(taskProvider.notifier).createTask(updated);
    if (created != null) {
      await ref.read(voiceAssistantProvider.notifier).speakConfirmation(created.title);
      widget.onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
                child: const Icon(LucideIcons.mic, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice Captured', style: CaliMindTypography.h3.copyWith(fontSize: 16)),
                  Text('Review & confirm before saving', style: CaliMindTypography.label),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onDismissed,
                icon: const Icon(LucideIcons.x, color: CaliMindColors.mutedForeground, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Title field
          Text('Task Title', style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: CaliMindColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CaliMindColors.cardFocusBorder),
            ),
            child: TextField(
              controller: _titleCtrl,
              style: CaliMindTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Category + Duration row
          Row(
            children: [
              Expanded(child: _buildCategorySelector()),
              const SizedBox(width: 12),
              Expanded(child: _buildPrioritySelector()),
            ],
          ),
          const SizedBox(height: 16),
          // Duration stepper
          _buildDurationStepper(),
          const SizedBox(height: 24),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: CaliMindColors.mindGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(LucideIcons.check, color: Colors.white, size: 18),
                label: Text(
                  'Add Task',
                  style: CaliMindTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskCategory>(
          value: _draft.category,
          dropdownColor: CaliMindColors.card,
          style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.foreground),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: CaliMindColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: CaliMindColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: CaliMindColors.cardBorder),
            ),
          ),
          items: TaskCategory.values.map((cat) => DropdownMenuItem(
            value: cat,
            child: Row(
              children: [
                Icon(cat.icon, size: 13, color: cat.color),
                const SizedBox(width: 6),
                Text(cat.label, style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.foreground)),
              ],
            ),
          )).toList(),
          onChanged: (cat) {
            if (cat != null) setState(() => _draft = _draft.copyWith(category: cat));
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((p) {
            final isSelected = _draft.priority == p;
            final (label, color) = switch (p) {
              1 => ('P1', CaliMindColors.destructive),
              2 => ('P2', CaliMindColors.warning),
              _ => ('P3', CaliMindColors.mutedForeground),
            };
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtils.selectionClick();
                  setState(() => _draft = _draft.copyWith(priority: p));
                },
                child: Container(
                  margin: EdgeInsets.only(right: p < 3 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : CaliMindColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? color : CaliMindColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(label, style: CaliMindTypography.bodySmall.copyWith(
                    color: isSelected ? color : CaliMindColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  )),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationStepper() {
    final quickDurations = [15, 30, 45, 60];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Duration', style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            // Stepper
            _StepperButton(
              icon: LucideIcons.minus,
              onTap: () {
                if (_draft.duration > 5) setState(() => _draft = _draft.copyWith(duration: _draft.duration - 5));
              },
            ),
            const SizedBox(width: 12),
            Text(
              _formatDuration(_draft.duration),
              style: CaliMindTypography.timeMonospace.copyWith(fontSize: 15),
            ),
            const SizedBox(width: 12),
            _StepperButton(
              icon: LucideIcons.plus,
              onTap: () {
                if (_draft.duration < 480) setState(() => _draft = _draft.copyWith(duration: _draft.duration + 5));
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Quick chips
        Wrap(
          spacing: 8,
          children: quickDurations.map((d) {
            final isSelected = _draft.duration == d;
            return GestureDetector(
              onTap: () => setState(() => _draft = _draft.copyWith(duration: d)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? CaliMindColors.primary.withOpacity(0.15) : CaliMindColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? CaliMindColors.primary : CaliMindColors.cardBorder,
                  ),
                ),
                child: Text(
                  '${d}m',
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: isSelected ? CaliMindColors.primary : CaliMindColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: CaliMindColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: Icon(icon, size: 14, color: CaliMindColors.foreground),
      ),
    );
  }
}
