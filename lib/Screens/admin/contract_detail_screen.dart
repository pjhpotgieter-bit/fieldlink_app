import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fieldlink_app/firebase_options.dart';
import 'package:fieldlink_app/services/invoice_pdf_service.dart';
import 'package:fieldlink_app/services/email_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldLink',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
          );
  }
}

class ContractDetailScreen extends StatelessWidget {
  final String contractId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const ContractDetailScreen({
    super.key,
    required this.contractId,
    required this.data,
    this.isAdmin = false,
  });

  Future<void> _approveContract(
    BuildContext context,
  ) async {
    try {
      final db =
          FirebaseFirestore.instance;

      final contractRef =
          db
              .collection('contracts')
              .doc(contractId);

      final contractSnap =
          await contractRef.get();

      if (!contractSnap.exists) {
        throw Exception(
          'Contract not found',
        );
      }

      final contractData =
          contractSnap.data()
              as Map<String, dynamic>;

      final counterRef =
          db
              .collection('counters')
              .doc('invoices');

      final invoiceRef =
          db.collection('invoices').doc();

      Map<String, dynamic>
          invoiceData = {};

      await db.runTransaction(
        (tx) async {
          final counterSnap =
              await tx.get(counterRef);

          int current = 1;

          if (counterSnap.exists) {
            current =
                counterSnap.data()?[
                        'current'] ??
                    1;
          } else {
            tx.set(counterRef, {
              'current': 1,
            });
          }

          final invoiceNumber =
              'INV-${current.toString().padLeft(5, '0')}';

          invoiceData = {
            'invoiceId':
                invoiceRef.id,

            'invoiceNumber':
                invoiceNumber,

            'contractId':
                contractId,

            /// BUYER
            'buyerId':
                contractData[
                        'buyerId'] ??
                    '',

            'buyerName':
                contractData[
                        'buyerName'] ??
                    '',

            'buyerEmail':
                contractData[
                        'buyerEmail'] ??
                    '',

            'buyerPhone':
                contractData[
                        'buyerPhone'] ??
                    '',

            'buyerAddress':
                contractData[
                        'buyerAddress'] ??
                    '',

            /// FARMER
            'farmerId':
                contractData[
                        'farmerId'] ??
                    '',

            'farmerName':
                contractData[
                        'farmerName'] ??
                    '',

            'farmName':
                contractData[
                        'farmName'] ??
                    '',

            /// PRODUCT
            'productName':
                contractData[
                        'productName'] ??
                    '',

            'quantity':
                contractData[
                        'quantity'] ??
                    0,

            'price':
                (contractData[
                            'price'] ??
                        0)
                    .toDouble(),

            'total':
                (contractData[
                            'quantity'] ??
                        0) *
                    (contractData[
                                'price'] ??
                            0)
                        .toDouble(),

            'notes':
                contractData[
                        'notes'] ??
                    '',

            /// STATUS
            'status': 'pending',

            'paymentStatus':
                'pending',

            'accepted': false,

            'paid': false,

            'farmerPaid': false,

            'createdAt':
                FieldValue
                    .serverTimestamp(),
          };

          /// UPDATE CONTRACT
          tx.update(contractRef, {
            'status': 'approved',

            'approvedAt':
                FieldValue
                    .serverTimestamp(),
          });

          /// CREATE INVOICE
          tx.set(
            invoiceRef,
            invoiceData,
          );

          /// UPDATE COUNTER
          tx.update(counterRef, {
            'current': current + 1,
          });
        },
      );

      /// GENERATE PDF
      final pdfBytes =
          await InvoicePdfService
              .generateInvoiceBytes(
        invoiceData,
      );

      /// SEND EMAIL (fire-and-forget)
      if ((invoiceData['buyerEmail'] ?? '').toString().isNotEmpty) {
        // Do not block the UI on email delivery. Start async send and report result separately.
        EmailService.sendInvoiceEmail(
          toEmail: invoiceData['buyerEmail'],
          invoiceNumber: invoiceData['invoiceNumber'],
          pdfBytes: pdfBytes,
        ).then((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email sent to buyer')),
          );
        }).catchError((e, st) {
          // Log the error and notify the user that invoice was created but email failed.
          // We keep the original success flow for invoice creation.
          print('Email send failed for invoice ${invoiceData['invoiceNumber']}: $e\n$st');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice created but email failed: $e')),
          );
        });
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approved — invoice created'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    }
  }

  Future<void> _rejectContract(
    BuildContext context,
  ) async {
    await FirebaseFirestore.instance
        .collection('contracts')
        .doc(contractId)
        .update({
      'status': 'rejected',
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text('Rejected'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product =
        data['productName'] ?? '';

    final quantity =
        data['quantity'] ?? 0;

    final price =
        (data['price'] ?? 0)
            .toDouble();

    final total =
        quantity * price;

    final status =
        data['status'] ?? 'pending';

    final buyerName =
        data['buyerName'] ?? '';

    final buyerEmail =
        data['buyerEmail'] ?? '';

    final buyerPhone =
        data['buyerPhone'] ?? '';

    final buyerAddress =
        data['buyerAddress'] ?? '';

    final farmerName =
        data['farmerName'] ?? '';

    final farmName =
        data['farmName'] ?? '';

    final notes =
        data['notes'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Contract Details',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [

            /// CONTRACT
            Card(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                        'Product: $product'),

                    Text(
                        'Quantity: $quantity'),

                    Text(
                        'Price: R$price'),

                    Text(
                        'Total: R$total'),

                    const SizedBox(
                        height: 8),

                    Text(
                        'Status: $status'),
                  ],
                ),
              ),
            ),

            const SizedBox(
                height: 16),

            /// BUYER
            Card(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    const Text(
                      'Buyer Details',
                      style: TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                        height: 8),

                    Text(
                        'Buyer: $buyerName'),

                    Text(
                        'Email: $buyerEmail'),

                    Text(
                        'Phone: $buyerPhone'),

                    Text(
                        'Address: $buyerAddress'),
                  ],
                ),
              ),
            ),

            const SizedBox(
                height: 16),

            /// FARMER
            Card(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    const Text(
                      'Farmer Details',
                      style: TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                        height: 8),

                    Text(
                        'Farmer: $farmerName'),

                    Text(
                        'Farm: $farmName'),

                    const SizedBox(
                        height: 8),

                    Text(
                        'Notes: $notes'),
                  ],
                ),
              ),
            ),

            const SizedBox(
                height: 20),

            if (isAdmin &&
                status == 'pending') ...[
              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton(
                  onPressed: () =>
                      _approveContract(
                    context,
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.green,
                  ),
                  child: const Text(
                    'Approve',
                  ),
                ),
              ),

              const SizedBox(
                  height: 10),

              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton(
                  onPressed: () =>
                      _rejectContract(
                    context,
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.red,
                  ),
                  child: const Text(
                    'Reject',
                  ),
                ),
              ),
            ],

            if (!isAdmin) ...[
              Text(
                'Waiting for admin approval...',
                style: TextStyle(
                  color:
                      Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}