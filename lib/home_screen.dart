import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _namaTugasController = TextEditingController();
  final _mataKuliahController = TextEditingController();
  DateTime? _selectedDeadline;
  bool _isAdding = false;
  bool _showSelesai = false;

  static const _bulanPendek = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
  static const _bulanPanjang = ['','Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];

  String _formatDate(DateTime d) => '${d.day} ${_bulanPendek[d.month]} ${d.year}';
  String _formatDateLong(DateTime d) => '${d.day} ${_bulanPanjang[d.month]} ${d.year}';

  @override
  void dispose() {
    _namaTugasController.dispose();
    _mataKuliahController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline(BuildContext context, StateSetter setSheetState) async {
    DateTime tempDate = _selectedDeadline ?? DateTime.now().add(const Duration(days: 1));
    int selectedYear = tempDate.year;
    int selectedMonth = tempDate.month;
    int selectedDay = tempDate.day;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
          if (selectedDay > daysInMonth) selectedDay = daysInMonth;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Pilih Deadline',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pickerRow('Tahun', Icons.calendar_today_outlined,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF6C63FF)),
                        onPressed: () => setDialogState(() {
                          if (selectedYear > DateTime.now().year) selectedYear--;
                        }),
                      ),
                      Text('$selectedYear',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF6C63FF)),
                        onPressed: () => setDialogState(() {
                          if (selectedYear < DateTime.now().year + 5) selectedYear++;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _pickerRow('Bulan', Icons.date_range_outlined,
                  DropdownButton<int>(
                    value: selectedMonth,
                    underline: const SizedBox(),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A3E),
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_bulanPanjang[i + 1], style: const TextStyle(color: Colors.white)),
                    )),
                    onChanged: (v) => setDialogState(() => selectedMonth = v!),
                  ),
                ),
                const SizedBox(height: 12),
                _pickerRow('Tanggal', Icons.today_outlined,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF6C63FF)),
                        onPressed: () => setDialogState(() {
                          if (selectedDay > 1) selectedDay--;
                        }),
                      ),
                      Text('$selectedDay',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF6C63FF)),
                        onPressed: () => setDialogState(() {
                          if (selectedDay < daysInMonth) selectedDay++;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.white38)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFE94560)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextButton(
                  onPressed: () {
                    final picked = DateTime(selectedYear, selectedMonth, selectedDay);
                    final todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    if (picked.isBefore(todayOnly)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Deadline tidak boleh sebelum hari ini!')));
                      return;
                    }
                    setSheetState(() => _selectedDeadline = picked);
                    setState(() => _selectedDeadline = picked);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Pilih', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pickerRow(String label, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _addTugas() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih deadline terlebih dahulu!')));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isAdding = true);
    try {
      await _firestore.collection('tugas').add({
        'namaTugas': _namaTugasController.text.trim(),
        'mataKuliah': _mataKuliahController.text.trim(),
        'deadline': Timestamp.fromDate(_selectedDeadline!),
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'userEmail': user.email,
        'isDone': false,
      });
      _namaTugasController.clear();
      _mataKuliahController.clear();
      setState(() => _selectedDeadline = null);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil ditambahkan!'),
              backgroundColor: Color(0xFF6C63FF)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _toggleDone(String docId, bool current) async =>
      await _firestore.collection('tugas').doc(docId).update({'isDone': !current});

  Future<void> _deleteTugas(String docId) async =>
      await _firestore.collection('tugas').doc(docId).delete();

  Future<void> _hapusSemuaSelesai(List<QueryDocumentSnapshot> doneDocs) async {
    final batch = _firestore.batch();
    for (final doc in doneDocs) batch.delete(doc.reference);
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua tugas selesai dihapus!'), backgroundColor: Colors.red));
  }

  void _showAddTugasSheet() {
    _namaTugasController.clear();
    _mataKuliahController.clear();
    setState(() => _selectedDeadline = null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1E2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFE94560)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Tambah Tugas Baru',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _darkField(_namaTugasController, 'Nama Tugas', Icons.assignment_outlined),
                    const SizedBox(height: 14),
                    _darkField(_mataKuliahController, 'Mata Kuliah', Icons.school_outlined),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _pickDeadline(context, setSheetState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                color: Color(0xFF6C63FF), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDeadline == null
                                  ? 'Pilih Deadline'
                                  : _formatDateLong(_selectedDeadline!),
                              style: TextStyle(
                                color: _selectedDeadline == null
                                    ? Colors.white38
                                    : Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            if (_selectedDeadline != null) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Ubah',
                                    style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isAdding ? null : _addTugas,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFFE94560)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isAdding
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Simpan Tugas',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
        errorStyle: const TextStyle(color: Color(0xFFE94560)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE94560))),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
    );
  }

  Color _deadlineColor(DateTime deadline) {
    final diff = deadline.difference(DateTime.now()).inDays;
    if (diff < 0) return const Color(0xFFE94560);
    if (diff <= 2) return Colors.orange.shade400;
    return const Color(0xFF4CAF50);
  }

  String _deadlineLabel(DateTime deadline) {
    final diff = deadline.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Terlambat';
    if (diff == 0) return 'Hari ini!';
    if (diff == 1) return 'Besok';
    return '$diff hari lagi';
  }

  Widget _tugasCard(QueryDocumentSnapshot doc, {bool isSelesai = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final deadline = (data['deadline'] as Timestamp).toDate();
    final isDone = data['isDone'] ?? false;
    final color = _deadlineColor(deadline);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade700]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) => _deleteTugas(doc.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: isSelesai
              ? LinearGradient(colors: [
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.02),
                ])
              : LinearGradient(colors: [
                  const Color(0xFF1E1E2E),
                  const Color(0xFF252535),
                ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelesai
                ? Colors.white.withOpacity(0.06)
                : color.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: isSelesai
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => _toggleDone(doc.id, isDone),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDone
                        ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                        : null,
                    color: isDone ? null : Colors.transparent,
                    border: Border.all(
                      color: isDone ? Colors.transparent : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['namaTugas'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isSelesai ? Colors.white24 : Colors.white,
                        decoration: isSelesai ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(isSelesai ? 0.1 : 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_outlined,
                                  size: 11,
                                  color: isSelesai
                                      ? Colors.white24
                                      : const Color(0xFF9D97FF)),
                              const SizedBox(width: 4),
                              Text(
                                data['mataKuliah'] ?? '',
                                style: TextStyle(
                                  color: isSelesai ? Colors.white24 : const Color(0xFF9D97FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  decoration: isSelesai ? TextDecoration.lineThrough : null,
                                  decorationColor: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isSelesai) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 11, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  _deadlineLabel(deadline),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isSelesai) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(_formatDate(deadline),
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email?.split('@').first ?? 'Mahasiswa';

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E), Color(0xFF0F3460)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -40, right: -40,
            child: Container(width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.1)))),
          Positioned(bottom: 100, left: -60,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFE94560).withOpacity(0.07)))),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('tugas').where('userId', isEqualTo: user?.uid).snapshots(),
              builder: (ctx, snapshot) {
                final allDocs = snapshot.data?.docs ?? [];
                final pendingDocs = allDocs.where((d) => (d.data() as Map)['isDone'] != true).toList()
                  ..sort((a, b) {
                    final aT = (a.data() as Map)['deadline'] as Timestamp;
                    final bT = (b.data() as Map)['deadline'] as Timestamp;
                    return aT.compareTo(bT);
                  });
                final doneDocs = allDocs.where((d) => (d.data() as Map)['isDone'] == true).toList();

                return CustomScrollView(
                  slivers: [
                    // ─── Header ───────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFFE94560)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Catatan Tugas Kuliah',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                                Text('Halo, $userName!',
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                              ],
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => FirebaseAuth.instance.signOut(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Icon(Icons.logout_rounded, color: Colors.white54, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Stats ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            _statCard('Total', allDocs.length.toString(),
                                Icons.list_alt_rounded, const Color(0xFF6C63FF), const Color(0xFF9D97FF)),
                            const SizedBox(width: 12),
                            _statCard('Selesai', doneDocs.length.toString(),
                                Icons.check_circle_outline, const Color(0xFF4CAF50), const Color(0xFF81C784)),
                            const SizedBox(width: 12),
                            _statCard('Pending', pendingDocs.length.toString(),
                                Icons.pending_actions_rounded, const Color(0xFFFF6B35), const Color(0xFFFFB347)),
                          ],
                        ),
                      ),
                    ),

                    // ─── Section Pending ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          children: [
                            Container(width: 3, height: 18,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFFE94560)],
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Tugas Pending  (${pendingDocs.length})',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: pendingDocs.isEmpty
                          ? SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Column(children: [
                                  Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
                                  const SizedBox(height: 8),
                                  Text('Tidak ada tugas pending',
                                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                                ]),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _tugasCard(pendingDocs[i]),
                                childCount: pendingDocs.length,
                              ),
                            ),
                    ),

                    // ─── Section Selesai ──────────────────────────────────
                    if (doneDocs.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _showSelesai = !_showSelesai),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 3, height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Selesai  (${doneDocs.length})',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                          color: Color(0xFF4CAF50))),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _konfirmasiHapusSelesai(doneDocs),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE94560).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE94560).withOpacity(0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete_sweep_outlined, size: 13, color: Color(0xFFE94560)),
                                          SizedBox(width: 4),
                                          Text('Hapus semua', style: TextStyle(fontSize: 11,
                                              color: Color(0xFFE94560), fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(_showSelesai ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: const Color(0xFF4CAF50)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showSelesai)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _tugasCard(doneDocs[i], isSelesai: true),
                              childCount: doneDocs.length,
                            ),
                          ),
                        ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFE94560)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddTugasSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Tambah Tugas', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }

  void _konfirmasiHapusSelesai(List<QueryDocumentSnapshot> doneDocs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Semua?',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text('${doneDocs.length} tugas selesai akan dihapus permanen.',
            style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white38)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade700]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () { Navigator.pop(ctx); _hapusSemuaSelesai(doneDocs); },
              child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color lightColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: lightColor, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: lightColor)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }
}