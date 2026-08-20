import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../services/realtime_service.dart';

class PartnerTab extends StatefulWidget {
  final String token;
  const PartnerTab({super.key, required this.token});

  @override
  State<PartnerTab> createState() => _PartnerTabState();
}

class _PartnerTabState extends State<PartnerTab> {
  bool _isLoading = true;
  bool _hasPartner = false;
  String? _partnerUsername;
  String? _partnerMood;
  bool _partnerIsSleeping = false;
  String? _partnerReturnTime;
  final _usernameController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${widget.token}',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _checkPartnerStatus();
    _eventSubscription = RealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      if (type == 'partner_status_changed' ||
          type == 'partner_accepted' ||
          type == 'partner_declined') {
        _checkPartnerStatus();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPartnerStatus() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/partners/status'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hasPartner = data['has_partner'] ?? false;
          if (_hasPartner) {
            _partnerUsername = data['username'];
            _partnerMood = data['mood'];
            _partnerIsSleeping = data['is_sleeping'] ?? false;
            _partnerReturnTime = data['return_time'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load partner status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPartner() async {
    if (_usernameController.text.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/partners/request?target_username=${Uri.encodeComponent(_usernameController.text)}'),
        headers: _authHeaders,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partner request sent to ${_usernameController.text}.')));
        _usernameController.clear();
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['detail'] ?? 'Request failed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _triggerAction(String action, [Map<String, dynamic>? data]) async {
    try {
      http.Response response;
      switch (action) {
        case 'send_message':
          response = await http.post(
            Uri.parse('$backendUrl/api/feed/?content_type=text&payload=${Uri.encodeComponent(data?['text'] ?? '')}'),
            headers: _authHeaders,
          );
          break;
        case 'set_return_time':
          response = await http.post(
            Uri.parse('$backendUrl/api/partners/return-time'),
            headers: _authHeaders,
            body: jsonEncode({'timestamp': data?['timestamp']}),
          );
          break;
        case 'set_timezone':
          response = await http.post(
            Uri.parse('$backendUrl/api/partners/timezone'),
            headers: _authHeaders,
            body: jsonEncode({
              'auto_detect': data?['auto'],
              'iana_timezone': data?['auto'] == true ? null : data?['timezone'],
            }),
          );
          break;
        case 'log_status':
          response = await http.post(
            Uri.parse('$backendUrl/api/partners/mood'),
            headers: _authHeaders,
            body: jsonEncode({'mood': data?['mood'], 'is_sleeping': data?['sleeping']}),
          );
          break;
        case 'save_quotes':
          response = await http.post(
            Uri.parse('$backendUrl/api/partners/quotes'),
            headers: _authHeaders,
            body: jsonEncode({
              'wake_hour': data?['wake_hour'],
              'wake_minute': data?['wake_minute'],
              'quotes': data?['quotes'],
            }),
          );
          break;
        case 'miss_you':
          response = await http.post(
            Uri.parse('$backendUrl/api/partners/miss-you'),
            headers: _authHeaders,
          );
          break;
        default:
          return;
      }

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "$action" sent.')));
        if (action == 'set_return_time' || action == 'log_status') {
          _checkPartnerStatus();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "$action" failed (${response.statusCode}).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showMessageDialog() {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Message"),
        content: TextField(controller: msgController, decoration: const InputDecoration(hintText: "Type message..."), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _triggerAction('send_message', {'text': msgController.text});
              Navigator.pop(context);
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  void _showDoodleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Draw Doodle"),
        content: SizedBox(width: 260, height: 280, child: DoodleCanvas(token: widget.token)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showReturnTimeDialog() async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _triggerAction('set_return_time', {'timestamp': dt.toIso8601String()});
  }

  void _showTimezoneDialog() {
    bool autoDetect = true;
    String selectedZone = "Europe/Berlin";
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Timezone Settings"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(title: const Text("Auto-detect via Location"), value: autoDetect, onChanged: (v) => setDialogState(() => autoDetect = v)),
              if (!autoDetect)
                DropdownButton<String>(
                  value: selectedZone,
                  isExpanded: true,
                  items: ["Europe/Berlin", "America/Vancouver", "America/New_York"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => selectedZone = v!),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                _triggerAction('set_timezone', {'auto': autoDetect, 'timezone': selectedZone});
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodSleepDialog() {
    String mood = _partnerMood ?? "Happy";
    bool isSleeping = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Log Status"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: mood,
                isExpanded: true,
                items: ["Happy", "Sad", "Tired", "Stressed", "Angry"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => mood = v!),
              ),
              SwitchListTile(title: const Text("Going to sleep"), value: isSleeping, onChanged: (v) => setDialogState(() => isSleeping = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                _triggerAction('log_status', {'mood': mood, 'sleeping': isSleeping});
                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuotesDialog() async {
    TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
    List<String> quotes = [];
    final quoteController = TextEditingController();

    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/partners/quotes'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        wakeTime = TimeOfDay(hour: data['wake_hour'] ?? 7, minute: data['wake_minute'] ?? 0);
        quotes = List<String>.from(data['quotes'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load quotes: $e')));
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Morning Quotes List"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text("Wake-up Time"),
                  trailing: Text(wakeTime.format(context)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: wakeTime);
                    if (t != null) setDialogState(() => wakeTime = t);
                  },
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: TextField(controller: quoteController, decoration: const InputDecoration(hintText: "Add quote"))),
                    IconButton(icon: const Icon(Icons.add), onPressed: () {
                      if (quoteController.text.isNotEmpty) {
                        setDialogState(() { quotes.add(quoteController.text); quoteController.clear(); });
                      }
                    })
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: quotes.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      title: Text(quotes[i]),
                      trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setDialogState(() => quotes.removeAt(i))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                _triggerAction('save_quotes', {
                  'wake_hour': wakeTime.hour,
                  'wake_minute': wakeTime.minute,
                  'quotes': quotes,
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPartner) {
      return RefreshIndicator(
        onRefresh: _checkPartnerStatus,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Partner Username', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _addPartner, child: const Text('Add Partner')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkPartnerStatus,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: Text(_partnerUsername ?? 'Partner'),
              subtitle: Text(_partnerIsSleeping
                  ? 'Sleeping'
                  : (_partnerMood != null ? 'Feeling $_partnerMood' : 'No status yet')),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.message), title: const Text("Send Message"), trailing: const Icon(Icons.chevron_right), onTap: _showMessageDialog),
          ListTile(leading: const Icon(Icons.draw), title: const Text("Draw Doodle"), trailing: const Icon(Icons.chevron_right), onTap: _showDoodleDialog),
          ListTile(leading: const Icon(Icons.schedule), title: const Text("Set Return Time"), trailing: const Icon(Icons.chevron_right), onTap: _showReturnTimeDialog),
          ListTile(leading: const Icon(Icons.public), title: const Text("Timezone Settings"), trailing: const Icon(Icons.chevron_right), onTap: _showTimezoneDialog),
          ListTile(leading: const Icon(Icons.mood), title: const Text("Log Mood & Sleep"), trailing: const Icon(Icons.chevron_right), onTap: _showMoodSleepDialog),
          ListTile(leading: const Icon(Icons.wb_sunny), title: const Text("Morning Quotes List"), trailing: const Icon(Icons.chevron_right), onTap: _showQuotesDialog),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.flash_on, color: Colors.red),
            title: const Text("Send 'Miss You'", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _triggerAction('miss_you'),
          ),
        ],
      ),
    );
  }
}

class DoodleCanvas extends StatefulWidget {
  final String token;
  const DoodleCanvas({super.key, required this.token});

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

class _DoodleCanvasState extends State<DoodleCanvas> {
  final GlobalKey _paintKey = GlobalKey();
  final int _gridSize = 80;
  late List<List<bool>> _pixels;
  Point<int>? _lastPoint;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _clearDoodle();
  }

  void _clearDoodle() => setState(() { _pixels = List.generate(_gridSize, (_) => List.filled(_gridSize, false)); _lastPoint = null; });

  void _drawPixelBlock(int x, int y) {
    if (x >= 0 && x < _gridSize && y >= 0 && y < _gridSize) {
      _pixels[y][x] = true;
      if (x < _gridSize - 1) _pixels[y][x + 1] = true;
      if (y < _gridSize - 1) _pixels[y + 1][x] = true;
      if (x < _gridSize - 1 && y < _gridSize - 1) _pixels[y + 1][x + 1] = true;
    }
  }

  void _drawLine(Point<int> p1, Point<int> p2) {
    int x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y;
    int dx = (x2 - x1).abs(), dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1, sy = y1 < y2 ? 1 : -1, err = dx - dy;
    while (true) {
      _drawPixelBlock(x1, y1);
      if (x1 == x2 && y1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) { err -= dy; x1 += sx; }
      if (e2 < dx) { err += dx; y1 += sy; }
    }
  }

  void _handleGesture(Offset globalPosition, {bool isNewStroke = false}) {
    final RenderBox? box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    int x = (box.globalToLocal(globalPosition).dx / box.size.width * _gridSize).floor();
    int y = (box.globalToLocal(globalPosition).dy / box.size.height * _gridSize).floor();
    if (x >= 0 && x < _gridSize && y >= 0 && y < _gridSize) {
      setState(() {
        Point<int> p = Point(x, y);
        (isNewStroke || _lastPoint == null) ? _drawPixelBlock(x, y) : _drawLine(_lastPoint!, p);
        _lastPoint = p;
      });
    }
  }

  Future<void> _sendDoodle() async {
    String hex = "";
    for (int y = 0; y < _gridSize; y++) {
      for (int x = 0; x < _gridSize; x += 8) {
        int byte = 0;
        for (int b = 0; b < 8; b++) { if (_pixels[y][x + b]) byte |= (1 << (7 - b)); }
        hex += byte.toRadixString(16).padLeft(2, '0');
      }
    }

    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/feed/?content_type=doodle&payload=$hex'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doodle sent!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send doodle (${response.statusCode}).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          key: _paintKey,
          width: 200,
          height: 200,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), color: Colors.white),
          child: GestureDetector(
            onPanDown: (d) => _handleGesture(d.globalPosition, isNewStroke: true),
            onPanUpdate: (d) => _handleGesture(d.globalPosition),
            onPanEnd: (_) => _lastPoint = null,
            child: CustomPaint(painter: DrawPainter(_pixels, _gridSize), size: const Size(200, 200)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: _isSending ? null : _clearDoodle, child: const Text("Clear")),
            ElevatedButton(
              onPressed: _isSending ? null : _sendDoodle,
              child: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Send"),
            ),
          ],
        )
      ],
    );
  }
}

class DrawPainter extends CustomPainter {
  final List<List<bool>> pixels;
  final int gridSize;
  DrawPainter(this.pixels, this.gridSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final w = size.width / gridSize, h = size.height / gridSize;
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (pixels[y][x]) canvas.drawRect(Rect.fromLTWH(x * w, y * h, w, h), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}