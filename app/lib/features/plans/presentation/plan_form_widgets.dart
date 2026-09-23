import 'package:flutter/material.dart';
import '../../../core/domain/local_date.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    required this.children,
    this.title,
    this.padding,
    super.key,
  });
  final List<Widget> children;
  final String? title;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Container(
      margin: EdgeInsets.only(bottom: theme.spacing.s20),
      padding: padding ?? EdgeInsets.all(theme.spacing.s16),
      decoration: skin.panel(),
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.s14),
                child: Text(title!, style: skin.label),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Figma's compact switch inside a full 48px semantic/touch target.
class PlanToggle extends StatelessWidget {
  const PlanToggle({required this.value, required this.onChanged, super.key});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: theme.minTapTarget,
          height: theme.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              // Animation: implicit track color/thumb alignment 200ms easeOut,
              // matching React's explicit AnimatedContainer switch annotation.
              duration: theme.motion.standard, curve: Curves.easeOut,
              width: PlanSkin.toggleWidth, height: PlanSkin.toggleHeight,
              padding: const EdgeInsets.all(PlanSkin.toggleInset),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? theme.primaryAction : theme.colors.outlineStrong,
                borderRadius: BorderRadius.circular(theme.radii.full),
              ),
              child: Container(
                width: PlanSkin.toggleThumb,
                height: PlanSkin.toggleThumb,
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlanTextField extends StatelessWidget {
  const PlanTextField({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint = '',
    this.error,
    this.onChanged,
    this.number = false,
    this.lines = 1,
    super.key,
  });
  final String label, hint;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? error;
  final ValueChanged<String>? onChanged;
  final bool number;
  final int lines;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s16),
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: skin.label),
          // Spacer: spacing.6 -> SizedBox(height: spacing.6)
          SizedBox(height: theme.spacing.s6),
          Container(
            decoration: skin.panel(compact: true, error: error != null),
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.s14),
            child: TextField(
              key: fieldKey,
              controller: controller,
              onChanged: onChanged,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    )
                  : TextInputType.text,
              minLines: lines,
              maxLines: lines == 1 ? 1 : null,
              style: skin.title,
              decoration: skin.input(hint).copyWith(errorText: error),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanDateTile extends StatelessWidget {
  const PlanDateTile({
    required this.label,
    required this.date,
    required this.onChanged,
    this.minimum,
    this.fieldKey,
    super.key,
  });
  final String label;
  final LocalDate date;
  final LocalDate? minimum;
  final Key? fieldKey;
  final ValueChanged<LocalDate> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: skin.label),
          SizedBox(height: theme.spacing.s6),
          Container(
            key: fieldKey,
            decoration: skin.panel(compact: true),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(theme.radii.md),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                minVerticalPadding: theme.spacing.s4,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.s14,
                ),
                title: Text(date.iso8601, style: skin.title),
                trailing: Icon(
                  Icons.calendar_today_outlined,
                  size: theme.typography.lg,
                ),
                onTap: () async {
                  final first = minimum == null
                      ? DateTime(PlanSkin.dateFirstYear)
                      : DateTime(minimum!.year, minimum!.month, minimum!.day);
                  final initial = DateTime(date.year, date.month, date.day);
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: initial.isBefore(first) ? first : initial,
                    firstDate: first,
                    lastDate: DateTime(PlanSkin.dateLastYear),
                  );
                  if (selected != null) {
                    onChanged(LocalDate.fromDateTime(selected));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanStatus extends StatelessWidget {
  const PlanStatus({this.message, this.onRetry, super.key});
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: message == null
            ? const CircularProgressIndicator()
            :
            // Flutter: Column, mainAxis: center, crossAxis: center
            Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message!, textAlign: TextAlign.center),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text(AppStrings.retry),
                    ),
                ],
              ),
      );
}

class PlanFailureTile extends StatelessWidget {
  const PlanFailureTile({
    required this.message,
    required this.onRetry,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: EdgeInsets.all(theme.spacing.s12),
      margin: EdgeInsets.only(bottom: theme.spacing.s12),
      decoration: PlanSkin(theme).panel(error: true),
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: PlanSkin(theme).caption.copyWith(color: theme.colors.danger),
          ),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

Future<bool> confirmPlanAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = AppStrings.confirmChange,
}) async {
  final theme = AppTheme.of(context);
  // Animation: confirmation fade 200ms easeOut (explicit route animation).
  return await showGeneralDialog<bool>(
        context: context,
        barrierColor:
            theme.colors.text.withValues(alpha: theme.opacities.overlay),
        transitionDuration: theme.motion.standard,
        transitionBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (context, _, __) => AlertDialog(
          title: Text(title),
          content: Text(message),
          titleTextStyle: Theme.of(context).textTheme.titleMedium,
          contentTextStyle: PlanSkin(theme).title,
          actions: [
            TextButton(
              style: PlanSkin(theme).textButton,
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              key: const Key('confirm-action'),
              style: PlanSkin(theme).textButton,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}
