import 'package:flutter/material.dart';
import '../services/partner_request_service.dart';

Future<void> checkAndShowPendingPartnerRequests(BuildContext context, String token) async {
  List<PendingPartnerRequest> requests;
  try {
    requests = await fetchPendingPartnerRequests(token);
  } catch (e) {
    return;
  }

  if (requests.isEmpty || !context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PartnerRequestDialog(token: token, initialRequests: requests),
  );
}

class PartnerRequestDialog extends StatefulWidget {
  final String token;
  final List<PendingPartnerRequest> initialRequests;

  const PartnerRequestDialog({
    super.key,
    required this.token,
    required this.initialRequests,
  });

  @override
  State<PartnerRequestDialog> createState() => _PartnerRequestDialogState();
}

class _PartnerRequestDialogState extends State<PartnerRequestDialog> {
  late List<PendingPartnerRequest> _requests;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _requests = List.of(widget.initialRequests);
  }

  Future<void> _handle(PendingPartnerRequest req, bool accept) async {
    setState(() => _processingIds.add(req.id));

    try {
      if (accept) {
        await acceptPartnerRequest(widget.token, req.id);
      } else {
        await declinePartnerRequest(widget.token, req.id);
      }

      if (!mounted) return;

      setState(() {
        _requests.removeWhere((r) => r.id == req.id);
        _processingIds.remove(req.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept
            ? 'You are now partners with ${req.senderUsername}!'
            : 'Declined request from ${req.senderUsername}.')),
      );

      if (_requests.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Partner Requests'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _requests.map((req) {
            final isProcessing = _processingIds.contains(req.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, color: Colors.pink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${req.senderUsername} wants to connect with you',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  isProcessing
                      ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _handle(req, false),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handle(req, true),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                  if (req != _requests.last) const Divider(),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: _requests.isEmpty
          ? null
          : [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
      ],
    );
  }
}