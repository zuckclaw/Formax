// Shell HomePage — bottom-nav, body switch, end-drawer + item drawer.
// Dipindah verbatim dari `lib/pages/home_page.dart` (Tahap 4c) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 2 situs setState didelegasikan ke helper State
// (_selectNavTab, _goToDashboardTab — extension dilarang memanggil
// protected member langsung); urutan + isi statement identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../home_page.dart';

extension _HomeShell on _HomePageState {
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) {
        // FIX: setiap ke TemplatePage selalu reload otomatis
        if (i == 1) {
          _ensureTemplatesLoaded();
        }
        _selectNavTab(i);
      },
      selectedItemColor: const Color(0xFF3B82F6),
      unselectedItemColor: const Color(0xFF94A3B8),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Template',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.drafts_outlined),
          label: 'Draft',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fact_check_outlined),
          label: 'Aktivitas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
      ],
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isSearching) {
      if (_isLoadingSearch) {
        return const Center(child: CircularProgressIndicator());
      }
      return SearchResultsView(
        searchData: _searchData,
        onRefresh: () {
          // You could re-trigger search here, or just let them clear it
          _onSearchChanged();
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildTemplateTab();
      case 2:
        return const DraftPage();
      case 3:
        return const ActivityPage();
      case 4:
        return const HistoryPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEndDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 52,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Form4x',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _drawerItem(Icons.grid_view_rounded, 'Dashboard', () {
            _goToDashboardTab();
            Navigator.pop(context);
          }, _selectedIndex == 0),
          _drawerItem(Icons.link, 'Join with Link', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinLinkPage()),
            );
          }, false),
          _drawerItem(Icons.qr_code_scanner, 'Scan QR', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQRPage()),
            );
          }, false),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ).then((updated) {
                      if (updated == true && mounted) {
                        _loadUserProfile();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE5E7EB),
                        child: Icon(Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF9CA3AF)),
                  onPressed: () async {
                    await ApiService.removeToken();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isSelected,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: isSelected ? const Color(0xFF1E40AF) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF1E40AF)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF1E40AF)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
