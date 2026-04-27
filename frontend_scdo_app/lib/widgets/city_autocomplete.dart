import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scdo_app/api_service.dart';
import 'package:scdo_app/theme/glass_theme.dart';

class CityAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Function(String)? onSelected;

  const CityAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.onSelected,
  });

  @override
  State<CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<CityAutocomplete> {
  final ApiService _apiService = ApiService();
  bool _isFetching = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty || textEditingValue.text.length < 2) {
              return const Iterable<String>.empty();
            }
            
            setState(() => _isFetching = true);
            try {
              final results = await _apiService.fetchCities(textEditingValue.text);
              return results;
            } finally {
              if (mounted) setState(() => _isFetching = false);
            }
          },
          onSelected: (String selection) {
            widget.controller.text = selection;
            if (widget.onSelected != null) widget.onSelected!(selection);
          },
          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
            return _AutocompleteField(
              fieldController: fieldController,
              parentController: widget.controller,
              focusNode: focusNode,
              label: widget.label,
              prefixIcon: widget.prefixIcon,
              isFetching: _isFetching,
              onSubmitted: onFieldSubmitted,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return _AutocompleteOptions(
              onSelected: onSelected,
              options: options,
              width: constraints.maxWidth,
            );
          },
        );
      }
    );
  }
}

class _AutocompleteField extends StatefulWidget {
  final TextEditingController fieldController;
  final TextEditingController parentController;
  final FocusNode focusNode;
  final String label;
  final IconData prefixIcon;
  final bool isFetching;
  final VoidCallback onSubmitted;

  const _AutocompleteField({
    required this.fieldController,
    required this.parentController,
    required this.focusNode,
    required this.label,
    required this.prefixIcon,
    required this.isFetching,
    required this.onSubmitted,
  });

  @override
  State<_AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<_AutocompleteField> {
  @override
  void initState() {
    super.initState();
    widget.fieldController.text = widget.parentController.text;
    widget.fieldController.addListener(_syncToParent);
    widget.parentController.addListener(_syncFromParent);
  }

  @override
  void dispose() {
    widget.fieldController.removeListener(_syncToParent);
    widget.parentController.removeListener(_syncFromParent);
    super.dispose();
  }

  void _syncToParent() {
    if (widget.parentController.text != widget.fieldController.text) {
      widget.parentController.text = widget.fieldController.text;
    }
    if (mounted) setState(() {}); // To show/hide clear button
  }

  void _syncFromParent() {
    if (widget.fieldController.text != widget.parentController.text) {
      widget.fieldController.text = widget.parentController.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.fieldController,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.prefixIcon, color: widget.prefixIcon == Icons.block ? GlassTheme.danger : null),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isFetching)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.accentCyan),
              ),
            if (widget.fieldController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  widget.fieldController.clear();
                  widget.focusNode.requestFocus();
                },
              ),
          ],
        ),
      ),
      onSubmitted: (value) => widget.onSubmitted(),
    );
  }
}

class _AutocompleteOptions extends StatelessWidget {
  final Function(String) onSelected;
  final Iterable<String> options;
  final double width;

  const _AutocompleteOptions({
    required this.onSelected,
    required this.options,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: width, 
          constraints: const BoxConstraints(maxHeight: 250),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e).withOpacity(0.98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (context, i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
              itemBuilder: (context, i) {
                final option = options.elementAt(i);
                return ListTile(
                  title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  dense: true,
                  hoverColor: GlassTheme.accentCyan.withOpacity(0.15),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
