// Navigasi & konfirmasi submit FillFormPage — tombol bawah, next/prev,
// dialog "masih ada yang kosong" dan "kirim jawaban".
// Dipindah verbatim dari `lib/pages/fillformpage.dart` (Tahap 3b) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 4 situs setState didelegasikan ke helper State
// (_goToPreviousPage, _goToNextPage, _jumpToQuestionPage — extension
// dilarang memanggil protected member langsung); urutan + isi identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../fillformpage.dart';

extension _FillFormNavigation on _FillFormPageState {
  Widget _buildNavigationButtons() {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (!isFirstPage)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goToPreviousPage(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Sebelumnya'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          if (!isFirstPage && !isLastPage) const SizedBox(width: 12),

          // Next / Submit button (mode pratinjau pemilik: tanpa Submit)
          Expanded(
            child: (_isOwnerPreview && isLastPage)
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text(
                          'Mode pratinjau',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (isLastPage) {
                              _showSubmitConfirmation();
                            } else {
                              _handleNext();
                            }
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isLastPage ? Icons.send : Icons.arrow_forward,
                            size: 18,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'Mengirim...'
                          : isLastPage
                          ? 'Submit'
                          : 'Selanjutnya',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPage
                          ? const Color(0xFF059669)
                          : const Color(0xFF1E66D0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT CONFIRMATION DIALOG
  // ============================================================
  void _handleNext() {
    final missing = _missingRequiredOnCurrentPage;
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wajib diisi di halaman ini: ${missing.take(3).map(_shortLabel).join(', ')}${missing.length > 3 ? ', ...' : ''}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    _goToNextPage();
  }

  void _showSubmitConfirmation() {
    final missing = _missingRequired;
    if (missing.isNotEmpty) {
      // Karena ada yang belum dijawab: lompat ke halaman pertama yang belum lengkap.
      if (_currentPage != _pageOfQuestion(missing.first)) {
        _jumpToQuestionPage(missing.first);
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 10),
              Text('Masih Ada yang Kosong'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${missing.length} soal wajib belum dijawab. Lengkapi dulu ya:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                ...missing
                    .take(8)
                    .map(
                      (q) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _shortLabel(q),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (missing.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'dan ${missing.length - 8} soal lainnya...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _jumpToQuestionPage(missing.first);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lengkapi'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send, color: Color(0xFF059669)),
            SizedBox(width: 12),
            Text('Kirim Jawaban?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu telah menjawab $_answeredCount dari ${_formData?.questions.length ?? 0} pertanyaan.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setelah dikirim, jawaban tidak bisa diubah lagi.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Kirim!'),
          ),
        ],
      ),
    );
  }
}
