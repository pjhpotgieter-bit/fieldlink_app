import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/farmer_dashboard.dart';
import '../config.dart';

class UploadPaymentProof extends StatefulWidget {
  final String paymentId;

  const UploadPaymentProof({super.key, required this.paymentId});

  @override
  State<UploadPaymentProof> createState() => _UploadPaymentProofState();
}

class _UploadPaymentProofState extends State<UploadPaymentProof> {

  bool _loading = false;

  Future<void> _uploadFile() async {
    if (!AppConfig.enablePayments) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payments are disabled')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
      withData: true,
    );

    if (result == null) return;

    setState(() => _loading = true);

    final fileBytes = result.files.first.bytes!;
    final fileName = result.files.first.name;

    final ref = FirebaseStorage.instance
        .ref()
        .child("payment_proofs/${widget.paymentId}/$fileName");

    await ref.putData(fileBytes);

    final downloadUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('payments')
        .doc(widget.paymentId)
        .update({
      'proofUrl': downloadUrl,
      'status': 'processing',
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proof uploaded")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Proof of Payment"),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _uploadFile,
                child: const Text("Upload File"),
              ),
      ),
    );
  }
}
