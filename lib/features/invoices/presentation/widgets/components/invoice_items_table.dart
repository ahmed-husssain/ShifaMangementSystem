import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../domain/invoice_model.dart';
import '../../../domain/invoice_constants.dart';

class InvoiceItemsTable extends StatelessWidget {
  final List<InvoiceItem> items;
  final List<TextEditingController>? daysControllers;
  final bool isEditable;
  final VoidCallback? onAddItem;
  final void Function(int index)? onRemoveItem;
  final void Function(int index, {String? name, double? price, int? qty})? onUpdateItem;

  const InvoiceItemsTable({
    super.key,
    required this.items,
    this.daysControllers,
    this.isEditable = true,
    this.onAddItem,
    this.onRemoveItem,
    this.onUpdateItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  child: Text(
                    '#',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const Expanded(
                  flex: 8,
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const Expanded(
                  flex: 4,
                  child: Text(
                    'DAILY CHARGES',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'DAYS',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const Expanded(
                  flex: 4,
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                if (isEditable) const SizedBox(width: 24),
              ],
            ),
          ),
          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];
              final isAlt = idx % 2 == 1;

              if (!isEditable) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAlt ? const Color(0xFFF8FAFC) : Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      Expanded(
                        flex: 8,
                        child: Text(
                          item.serviceName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          NumberFormat('#,###').format(item.price),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          NumberFormat('#,###').format(item.total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlt ? const Color(0xFFF8FAFC) : Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text('', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    // Service Selector
                    Expanded(
                      flex: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            value: InvoiceConstants.standardPrices.containsKey(item.serviceName)
                                ? item.serviceName
                                : (item.serviceName.isEmpty ? null : item.serviceName),
                            hint: const Text('Select Service', style: TextStyle(fontSize: 11)),
                            items: [
                              ...InvoiceConstants.standardServices.map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                  )),
                              if (item.serviceName.isNotEmpty && !InvoiceConstants.standardServices.contains(item.serviceName))
                                DropdownMenuItem(
                                  value: item.serviceName,
                                  child: Text(item.serviceName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                final defaultPrice = InvoiceConstants.standardPrices[val] ?? 0.0;
                                onUpdateItem?.call(
                                  idx,
                                  name: val,
                                  price: defaultPrice > 0 ? defaultPrice : null,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Daily Price Input
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: TextFormField(
                          key: Key('price__'),
                          initialValue: item.price > 0 ? item.price.toStringAsFixed(0) : '',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            hintText: '0',
                          ),
                          onChanged: (val) => onUpdateItem?.call(
                            idx,
                            price: double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Days Input
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: Builder(
                          builder: (context) {
                            if (daysControllers != null) {
                              while (daysControllers!.length <= idx) {
                                daysControllers!.add(TextEditingController(text: item.quantity.toString()));
                              }
                              return TextFormField(
                                controller: daysControllers![idx],
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                  hintText: '1',
                                ),
                                onChanged: (val) {
                                  final qty = int.tryParse(val) ?? 1;
                                  onUpdateItem?.call(idx, qty: qty);
                                },
                              );
                            }
                            return TextFormField(
                              key: Key('qty__'),
                              initialValue: item.quantity.toString(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                                hintText: '1',
                              ),
                              onChanged: (val) {
                                final qty = int.tryParse(val) ?? 1;
                                onUpdateItem?.call(idx, qty: qty);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Amount
                    Expanded(
                      flex: 4,
                      child: Text(
                        NumberFormat('#,###').format(item.total),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    // Remove Button
                    SizedBox(
                      width: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, color: Colors.red, size: 16),
                        onPressed: () => onRemoveItem?.call(idx),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (isEditable && onAddItem != null)
            InkWell(
              onTap: onAddItem,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: const Center(
                  child: Text(
                    '+ Add Service Row',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
