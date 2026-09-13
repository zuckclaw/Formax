// lib/pages/home_page.dart
// Halaman utama aplikasi Form4x.
// Berisi Dashboard, Template, dan History dalam satu layar dengan BottomNavigationBar.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/form_model.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../data/mock_data.dart';
import '../widgets/template_card.dart';
import '../widgets/search_results_view.dart';
import 'login_page.dart';
import 'formmakerpage.dart';
import 'historypage.dart';
import 'draft_page.dart';
import 'join_link_page.dart';
import 'activity_page.dart';
import 'scan_qr_page.dart';
import 'profile_page.dart';

// Part: widget tab Dashboard — Tahap 4a.
// Sama-sama satu library, call-site tidak berubah.
part 'home/dashboard_part.dart';

// Part: widget tab Template — Tahap 4b.
// Sama-sama satu library, call-site tidak berubah.
part 'home/template_part.dart';

// Part: shell (bottom-nav, body, drawer) — Tahap 4c.
// Sama-sama satu library, call-site tidak berubah.
part 'home/shell_part.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _fullName = 'User';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  bool _isLoadingSearch = false;
  Map<String, dynamic> _searchData = {};

  List<FormTemplate> _myTemplates = [];
  bool _isLoadingTemplates = false;
  bool _templatesLoaded = false;

  Future<List<FormModel>>? _recentFormsFuture;
  Future<List<FormModel>>? _draftFormsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    _loadUserProfile();
    // FIX: Template tidak di-load otomatis saat refresh/app start.
    // Hanya di-load saat user masuk tab Template atau setelah konfirmasi simpan.
    _searchController.addListener(_onSearchChanged);
  }

  void _refreshDashboard() {
    _recentFormsFuture = _fetchRecentForms();
    _draftFormsFuture = _fetchDraftForms();
  }

  // Helper navigasi/refresh untuk extension display (home/dashboard_part.dart
  // & home/template_part.dart): setState HANYA di member State.
  // Isi = pindahan verbatim tiap situs setState display.
  void _refreshDashboardNow() {
    setState(_refreshDashboard);
  }

  // "Lihat semua" → tab History (index 4 = HistoryPage di _buildBody).
  void _goToHistoryTab() {
    setState(() {
      _selectedIndex = 4;
    });
  }

  // Helper tab untuk extension template (home/template_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim.
  // index 0 = Dashboard, 1 = Template (lihat _buildBody).
  void _goToDashboardTab() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _goToTemplateTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  // Helper bottom-nav untuk extension shell (home/shell_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim.
  void _selectNavTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<List<FormModel>> _fetchRecentForms() async {
    final res = await ApiService.getMyForms();
    if (res['success'] == true) {
      final rawList = res['data'];
      if (rawList is! List) return [];
      var forms = rawList.map((e) => FormModel.fromJson(e as Map)).toList();
      forms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (forms.length > 10) forms = forms.sublist(0, 10);
      return forms;
    }
    return [];
  }

  Future<List<FormModel>> _fetchDraftForms() async {
    final res = await ApiService.getDraftForms();
    if (res['success'] == true) {
      final rawList = res['data'];
      if (rawList is! List) return [];
      final drafts = rawList.map((e) => FormModel.fromJson(e as Map)).toList();
      drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return drafts;
    }
    return [];
  }

  Future<void> _openDraftEditor(String formId) async {
    final res = await ApiService.getForm(formId);
    if (!mounted) return;
    if (res['success'] != true || res['data'] is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat draft: ${res['message']}')),
      );
      return;
    }
    final formJson = Map<String, dynamic>.from(res['data'] as Map);
    await Navigator.push<FormMakerResult>(
      context,
      MaterialPageRoute(builder: (_) => FormMakerPage(initialDraft: formJson)),
    );
    if (!mounted) return;
    setState(_refreshDashboard);
  }

  Future<void> _ensureTemplatesLoaded() async {
    // FIX: setiap ke TemplatePage selalu reload otomatis (sesuai request user)
    _templatesLoaded = true;
    await _loadMyTemplates();
  }

  Future<void> _loadMyTemplates() async {
    if (mounted) {
      setState(() {
        _isLoadingTemplates = true;
      });
    }
    final res = await ApiService.getMyTemplates();
    if (!mounted) return;
    setState(() {
      _isLoadingTemplates = false;
      if (res['success'] == true) {
        final rawList = res['data'] as List<dynamic>;
        _myTemplates = rawList
            .map((e) => FormTemplate.fromJson(e as Map))
            .toList();
      } else {
        debugPrint('[Home] getMyTemplates gagal: ${res['message']}');
      }
    });
  }

  Future<void> _refreshTemplatesImmediately() async {
    _templatesLoaded = true;
    await _loadMyTemplates();
  }

  void _addTemplateOptimistically(FormTemplate t) {
    // Langsung terload otomatis tanpa menunggu fetch server
    setState(() {
      // Hindari duplikat id
      if (t.id != null && _myTemplates.any((e) => e.id == t.id)) return;
      _myTemplates = [..._myTemplates, t];
    });
    // Sync dengan server di background untuk pastikan konsisten
    _refreshTemplatesImmediately();
  }

  Future<void> _deleteTemplate(FormTemplate tpl) async {
    if (tpl.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text('Hapus Template'),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus template "${tpl.plainTitle}"? '
          'Tindakan ini tidak bisa dibatalkan.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await ApiService.deleteTemplate(tpl.id!);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _myTemplates = _myTemplates.where((e) => e.id != tpl.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template berhasil dihapus')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus template: ${res['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _isLoadingSearch = false;
        _searchData = {};
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await ApiService.search(query);
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
          if (result['success'] == true) {
            final raw = result['data'];
            _searchData = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
          } else {
            _searchData = {};
          }
        });
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final result = await ApiService.getMe();
    if (result['success'] == true && mounted) {
      setState(() {
        _fullName = result['data']['full_name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      endDrawer: _buildEndDrawer(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0B76D4),
      foregroundColor: Colors.white,
      centerTitle: false,
      leading: GestureDetector(
        onTap: () {},
        child: Container(
          margin: const EdgeInsets.all(5),
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: SvgPicture.asset(
              'assets/icons/logoss.svg',
              width: 27,
              height: 27,
              fit: BoxFit.cover,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Form4x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Tempat membuat Form terlengkap',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Cari formulir...',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black38),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocus.unfocus();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────

  // NOTE (Tahap 4c): _buildBottomNav & _buildBody pindah ke
  // home/shell_part.dart; setState nav didelegasikan ke _selectNavTab
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 4a): _buildDashboardTab, _buildDraftSection, _buildDraftCard
  // pindah ke home/dashboard_part.dart (tanpa perubahan logika/call-site).

  // NOTE (Tahap 4a): _buildRecentSection, _buildGreetingCard pindah ke
  // home/dashboard_part.dart; setState "Lihat semua"/refresh didelegasikan
  // ke _goToHistoryTab/_refreshDashboardNow (isi statement identik).

  // NOTE (Tahap 4a): _buildFormCard pindah ke home/dashboard_part.dart.

  // NOTE (Tahap 4a): _buildStatusBadge, _buildEmptyState, _formatDate
  // pindah ke home/dashboard_part.dart (_formatDate hanya dipakai kartu
  // dashboard — sudah dicek tidak ada pemakai lain).

  // ─── Template Tab ─────────────────────────────────────────────────────────

  // NOTE (Tahap 4b): _buildTemplateTab pindah ke home/template_part.dart;
  // 4 situs setState didelegasikan ke _refreshDashboardNow/_goToDashboardTab/
  // _goToTemplateTab di atas (urutan + isi statement identik).
  // Tanpa perubahan logika/call-site.

  // NOTE (Tahap 4c): _buildEndDrawer & _drawerItem pindah ke
  // home/shell_part.dart; setState item Dashboard didelegasikan ke
  // _goToDashboardTab (urutan + isi statement identik).
  // Tanpa perubahan logika/call-site.
}
