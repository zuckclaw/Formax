// Widget tab Template HomePage — template bawaan + template saya.
// Dipindah verbatim dari `lib/pages/home_page.dart` (Tahap 4b) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 4 situs setState didelegasikan ke helper State
// (_refreshDashboardNow, _goToDashboardTab, _goToTemplateTab — extension
// dilarang memanggil protected member langsung); urutan + isi identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../home_page.dart';

extension _HomeTemplate on _HomePageState {
  Widget _buildTemplateTab() {
    // FIX: setiap ke TemplatePage selalu auto-reload (sesuai request user)
    if (!_templatesLoaded && !_isLoadingTemplates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureTemplatesLoaded();
      });
    }
    return RefreshIndicator(
      onRefresh: _loadMyTemplates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Bawaan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: MockData.builtInTemplates.length,
                itemBuilder: (context, index) {
                  final t = MockData.builtInTemplates[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 160,
                      child: TemplateCard(template: t, isBuiltIn: true),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Template Saya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<FormMakerResult>(
                      context,
                      MaterialPageRoute(builder: (_) => const FormMakerPage()),
                    );
                    if (!mounted) return;
                    if (result != null && result.savedTemplate) {
                      _addTemplateOptimistically(result.template!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${result.template!.plainTitle} berhasil disimpan!',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    } else {
                      _refreshDashboardNow();
                      _refreshTemplatesImmediately();
                      if (result != null && result.savedDraft) {
                        _goToDashboardTab();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Draft berhasil disimpan — lihat di Dashboard',
                            ),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Daftar diperbarui'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      }
                    }
                    if (result == null || !result.savedDraft) {
                      _goToTemplateTab();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Buat Baru'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingTemplates)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_myTemplates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Belum ada template yang disimpan.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadMyTemplates,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Muat Ulang'),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // FIX: mainAxisExtent (tinggi pasti) bukan childAspectRatio, supaya
                  // kartu template tidak tampak tinggi/memanjang saat sel di-stretch.
                  mainAxisExtent: 190,
                ),
                itemCount: _myTemplates.length,
                itemBuilder: (context, index) {
                  return TemplateCard(
                    template: _myTemplates[index],
                    isBuiltIn: false,
                    onDelete: () => _deleteTemplate(_myTemplates[index]),
                    onSaved: (result) async {
                      if (result != null && result.savedTemplate) {
                        _addTemplateOptimistically(result.template!);
                      } else {
                        await _refreshTemplatesImmediately();
                        if (result != null && result.savedDraft) {
                          _refreshDashboardNow();
                        }
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
