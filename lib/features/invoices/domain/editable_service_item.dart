import 'package:flutter/material.dart';

class EditableServiceItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController daysController;
  bool isNewlyAdded;

  EditableServiceItem({
    required String serviceName,
    required double price,
    required int days,
    this.isNewlyAdded = false,
    VoidCallback? onChanged,
  })  : nameController = TextEditingController(text: serviceName),
        priceController = TextEditingController(text: price > 0 ? price.toStringAsFixed(0) : '0'),
        daysController = TextEditingController(text: days > 0 ? days.toString() : '1') {
    if (onChanged != null) {
      nameController.addListener(onChanged);
      priceController.addListener(onChanged);
      daysController.addListener(onChanged);
    }
  }

  double get price => double.tryParse(priceController.text.trim()) ?? 0.0;
  int get days => int.tryParse(daysController.text.trim()) ?? 0;
  double get total => price * days;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    daysController.dispose();
  }
}
