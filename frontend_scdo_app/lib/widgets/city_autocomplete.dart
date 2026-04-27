import 'package:flutter/material.dart';
import 'package:scdo_app/api_service.dart';
import 'package:scdo_app/theme/glass_theme.dart';

class CityAutocomplete extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return await apiService.fetchCities(textEditingValue.text);
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (onSelected != null) onSelected!(selection);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        // Sync the internal fieldController with the passed-in controller
        if (fieldController.text != controller.text) {
          fieldController.text = controller.text;
        }

        // We use a listener to keep the parent controller updated as the user types
        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.text = fieldController.text;
          }
        });

        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(prefixIcon, color: prefixIcon == Icons.block ? GlassTheme.danger : null),
          ),
          onSubmitted: (value) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            child: Container(
              width: 300,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                      title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      dense: true,
                      hoverColor: GlassTheme.accentCyan.withOpacity(0.1),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
