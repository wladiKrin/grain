import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';

InputDecoration editorDecoration(BuildContext context, String label) {
  final g = context.grain;
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderSide: BorderSide(color: g.border)),
    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: g.border)),
    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: g.ink)),
  );
}

class EditorTextField extends StatelessWidget {
  const EditorTextField({
    super.key,
    required this.label,
    required this.controller,
    this.number = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool number;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: editorDecoration(context, label),
    ),
  );
}

class EditorDropdown<T> extends StatelessWidget {
  const EditorDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InputDecorator(
      decoration: editorDecoration(context, label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          elevation: 0,
          dropdownColor: context.grain.ground,
          items: [
            for (final e in items.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    ),
  );
}

class EditorSection extends StatelessWidget {
  const EditorSection(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(text.toUpperCase(), style: context.grain.label),
  );
}

/// Chips that fill [controller] with a known value (mount suggestions).
class MountSuggestions extends StatelessWidget {
  const MountSuggestions({
    super.key,
    required this.mounts,
    required this.controller,
  });

  final List<String> mounts;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      children: [
        for (final m in mounts)
          ActionChip(label: Text(m), onPressed: () => controller.text = m),
      ],
    ),
  );
}

/// The editor's save error, under the form.
class EditorError extends StatelessWidget {
  const EditorError(this.text, {super.key});
  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            text!,
            style: TextStyle(color: context.grain.accent, fontSize: 14),
          ),
        );
}

Future<bool> confirmDelete(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: context.grain.ground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.grain.border),
      ),
      title: Text('Delete $name?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
