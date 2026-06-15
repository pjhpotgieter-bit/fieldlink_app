import 'package:flutter/material.dart';
import 'package:fieldlink_app/services/invoice_pdf_service.dart';
import 'package:fieldlink_app/services/invoice_number_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fieldlink_app/services/email_service.dart';

class AdminInvoiceGeneratorScreen extends StatefulWidget {
  const AdminInvoiceGeneratorScreen({super.key});

  @override
  State<AdminInvoiceGeneratorScreen> createState() =>
      _AdminInvoiceGeneratorScreenState();
}

class _AdminInvoiceGeneratorScreenState
    extends State<AdminInvoiceGeneratorScreen> {

      @override
  void initState() {
    super.initState();
    _loadInvoiceNumber();
  }
  Future<void> _loadInvoiceNumber() async {
    try {
      final number = await invoiceNumberService.getNextInvoiceNumber();

      if (!mounted) return;
      setState(() {
        invoiceNumberController.text = number;
      });
      
    } catch (e) {
      invoiceNumberController.text = 'Error loading number';
    }
  } 
    
   
  final _formKey = GlobalKey<FormState>();
  final invoiceNumberService = InvoiceNumberService();

  final invoiceNumberController = TextEditingController();
  final buyerNameController = TextEditingController();
  final buyerEmailController = TextEditingController();
  final buyerPhoneController = TextEditingController();
  final buyerAddressController = TextEditingController();

  final farmerNameController = TextEditingController();
  final farmNameController = TextEditingController();

  final productNameController = TextEditingController();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();

  final subtotalController = TextEditingController();
  final vatController = TextEditingController();
  final totalController = TextEditingController();
  final notesController = TextEditingController();

  void calculateTotals() {
    final quantity = double.tryParse(quantityController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;

    final subtotal = quantity * price;
    final vat = subtotal * 0.15;
    final total = subtotal + vat;

    subtotalController.text = subtotal.toStringAsFixed(2);
    vatController.text = vat.toStringAsFixed(2);
    totalController.text = total.toStringAsFixed(2);
    setState(() {});
  }

  @override
  void dispose() {
    invoiceNumberController.dispose();
    buyerNameController.dispose();
    buyerEmailController.dispose();
    buyerPhoneController.dispose();
    buyerAddressController.dispose();
    farmerNameController.dispose();
    farmNameController.dispose();
    productNameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    subtotalController.dispose();
    vatController.dispose();
    totalController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final invoiceNumber = await invoiceNumberService.getNextInvoiceNumber();
      invoiceNumberController.text = invoiceNumber;

      final quantity = double.tryParse(quantityController.text) ?? 0;
      final price = double.tryParse(priceController.text) ?? 0;
      final subtotal = double.tryParse(subtotalController.text) ?? 0;
      final vat = double.tryParse(vatController.text) ?? 0;
      final total = double.tryParse(totalController.text) ?? 0;

      await InvoicePdfService.generateInvoice({
        'invoiceNumber': invoiceNumber,
        'buyerName': buyerNameController.text,
        'buyerEmail': buyerEmailController.text,
        'buyerPhone': buyerPhoneController.text,
        'buyerAddress': buyerAddressController.text,
        'farmerName': farmerNameController.text,
        'farmName': farmNameController.text,
        'productName': productNameController.text,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
        'vat': vat,
        'total': total,
        'notes': notesController.text,
        'date': DateTime.now().toString(),
      });

      final invoiceData = {
        'invoiceNumber': invoiceNumber,
        'buyerName': buyerNameController.text,
        'buyerEmail': buyerEmailController.text,
        'buyerPhone': buyerPhoneController.text,
        'buyerAddress': buyerAddressController.text,
        'farmerName': farmerNameController.text,
        'farmName': farmNameController.text,
        'productName': productNameController.text,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
        'vat': vat,
        'total': total,
        'notes': notesController.text,
        'date': DateTime.now().toString(),
      };

      await InvoicePdfService.generateInvoice(
        invoiceData
        );

      await FirebaseFirestore.instance
          .collection('invoices')
          .add({
            ...invoiceData,
            'status': 'pending',
            'paymentStatus': 'pending',
            'accepted': false,
            'paid': false,
            'farmerPaid': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final pdfBytes = await InvoicePdfService.generateInvoiceBytes(
            invoiceData,
          );

          
          // Fire-and-forget email send so UI isn't blocked by delivery issues.
          if ((buyerEmailController.text ?? '').isNotEmpty) {
            EmailService.sendInvoiceEmail(
              toEmail: buyerEmailController.text,
              invoiceNumber: invoiceNumber,
              pdfBytes: pdfBytes,
            ).then((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email sent to buyer')),
              );
            }).catchError((e, st) {
              print('Email send failed for invoice $invoiceNumber: $e\n$st');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invoice created but email failed: $e')),
              );
            });
          }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice generated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating invoice: $e')),
      );
    }
  }

  Widget buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    void Function(String)? onChanged,
     }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(      
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: (value) {
          if (!readOnly && (value == null || value.isEmpty)) {
            return 'enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: 
            BorderRadius.circular(10),
          ),
          ),
        ),
      );
       
    }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Invoice Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildField(
                'Invoice Number',
                invoiceNumberController,
                readOnly: true,
              ),
              buildField('Buyer Name', buyerNameController),
              buildField('Buyer Email', buyerEmailController),
              buildField('Buyer Phone', buyerPhoneController),
              buildField('Buyer Address', buyerAddressController),
              buildField('Farmer Name', farmerNameController),
              buildField('Farm Name', farmNameController),
              buildField('Product Name', productNameController),
              buildField(
                'Quantity',
                quantityController,
                keyboardType: TextInputType.number,
                onChanged: (_) => calculateTotals(),
              ),
              buildField(
                'Price',
                priceController,
                keyboardType: TextInputType.number,
                onChanged: (_) => calculateTotals(),
              ),
              buildField(
                'Subtotal',
                subtotalController,
                readOnly: true,
              ),
              buildField(
                'VAT',
                vatController,
                readOnly: true,
              ),
              buildField(
                'Total',
                totalController,
                readOnly: true,
              ),

             
              buildField('Notes', notesController),
          
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _generateInvoice,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Generate Invoice PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}