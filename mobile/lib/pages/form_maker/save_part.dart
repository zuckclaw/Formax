// Pipeline simpan FormMakerPage — settings publish, status-only save,
// sinkron editor, save form (draft/publish).
// Dipindah verbatim dari `lib/pages/formmakerpage.dart` (Tahap 6c1) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 3 situs setState didelegasikan ke helper State
// (_replaceBuilderState, _markSaving, _markSavingDoneIfMounted — extension
// dilarang memanggil protected member langsung); urutan + isi identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../formmakerpage.dart';

extension _FormMakerSave on _FormMakerPageState {
  Map<String, dynamic> _buildPublishSettings() {
    // Fix: sesuaikan dengan web â€” hanya kirim start/end_date jika Form Timer benar-benar butuh window
    // Jika Enable Timer OFF atau mode 'Start when respondent opens' (per-responden, bukan window global) â†’ jangan kirim window
    // Ini yang sebelumnya bikin publish langsung 403 'Form belum dibuka' karena start_date = now future + naive WIB mismatch
    DateTime? startDate;
    DateTime? endDate;
    final isPerRespondent =
        _timerMode == 'Start when respondent opens the form';
    if (!_enableTimer || isPerRespondent) {
      startDate = null;
      endDate = null;
    } else {
      // Start at specific date and time â†’ window global.
      // Backend mengharapkan format waktu LOKAL (WIB) tanpa zona (seperti datetime-local di web).
      // Kurangi 5 menit (bukan 60s) untuk mencegah error "Form belum dibuka" jika jam HP lebih cepat dari server.
      startDate =
          _startDate ?? DateTime.now().subtract(const Duration(minutes: 5));
      endDate = _endDate ?? startDate.add(_getDurationValueAsDuration());
    }

    // Batas respons: 1 kali / tanpa batas / kustom (>= 2) â€” seperti web.
    int maxSub;
    switch (_submissionLimit) {
      case 'unlimited':
        maxSub = 0;
        break;
      case 'custom':
        final n = int.tryParse(_customSubLimitCtrl.text.trim()) ?? 1;
        maxSub = n >= 2 ? n : 1;
        break;
      case 'once':
      default:
        maxSub = 1;
    }

    return {
      'allow_see_result': _correctAnswers,
      'max_submissions': maxSub,
      'require_fullscreen': _requireFullscreen,
      'reveal_answers': _revealAnswers,
      'accept_responses': _acceptResponses,
      'status': _formStatus,
      'shuffle_questions': _shuffleQuestions,
      'shuffle_options': _shuffleOptions,
      'use_join_token': _useJoinToken,
      // Kirim waktu lokal tanpa Z, sesuai ekspektasi backend (seperti datetime-local)
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  // Simpan sebagian (status-only): dipakai saat PATCH atomik gagal karena
  // soal terkunci (409) atau tidak valid (422). Mengirim ulang field
  // non-soal TANPA questions ke endpoint PATCH yang sama, lalu me-refresh
  // editor dari data kanonis server agar tidak tampilkan soal basi.
  // Return: {'success', 'data', 'questionsLocked'|'questionsNotSaved'}.
  Future<Map<String, dynamic>> _saveStatusOnly({
    required String formId,
    required String titleHtml,
    required String descriptionHtml,
    required Map<String, dynamic> settings,
    required String originalError,
  }) async {
    final msgLower = originalError.toLowerCase();
    final isLocked = msgLower.contains('sudah punya jawaban');
    final statusOnlyPayload = <String, dynamic>{
      'title': titleHtml,
      'description': descriptionHtml,
      'banner_url': _builderState.bannerUrl,
      ...settings,
    };
    final patched = await ApiService.updateForm(formId, statusOnlyPayload);
    if (patched['success'] != true) return patched;
    Map<String, dynamic>? canonical;
    if (patched['data'] is Map) {
      canonical = Map<String, dynamic>.from(patched['data'] as Map);
    }
    try {
      final saved = await ApiService.getForm(formId);
      if (saved['success'] == true && saved['data'] is Map) {
        canonical = Map<String, dynamic>.from(saved['data'] as Map);
      }
    } catch (_) {}
    return {
      'success': true,
      'data': canonical ?? {'id': formId},
      if (isLocked) 'questionsLocked': true,
      if (!isLocked) ...{
        'questionsNotSaved': true,
        'questionsError': originalError,
      },
    };
  }

  // Sinkronkan editor ke data kanonis server (dipanggil setelah partial save
  // agar soal yang ditolak backend tidak tetap tampil sebagai sudah tersimpan).
  void _syncEditorFromServerData(Map<String, dynamic> data) {
    try {
      _applyFormSettings(data);
      final fresh = FormBuilderState.fromForm(data);
      final old = _builderState;
      _replaceBuilderState(fresh);
      old.dispose();
    } catch (e) {
      debugPrint('[FormMaker] sync editor gagal: $e');
    }
  }

  // Simpan draft/publish form ke /forms. Kalau sudah punya _draftFormId,
  // pakai PATCH (update field + replace questions) supaya tidak duplikat.
  Future<Map<String, dynamic>?> _saveForm({required bool publish}) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return null;
    _markSaving();
    try {
      _syncTitleFromPage();

      final titleHtml = _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul';
      final descriptionHtml = _builderState.formDescription.trim();
      final questionsPayload = _builderState.buildApiPayload();
      final settings = _buildPublishSettings();
      // Tombol Publish selalu menghasilkan status published (seperti web).
      if (publish) settings['status'] = 'published';

      Map<String, dynamic> res;
      if (_draftFormId != null) {
        res = await ApiService.updateForm(_draftFormId!, {
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          ...settings,
          'questions': questionsPayload,
        });
      } else {
        res = await ApiService.createForm({
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          'slug': ApiService.generateSlug(QuillHtml.htmlToPlainText(titleHtml)),
          'questions': questionsPayload,
          ...settings,
          if (_useJoinToken) 'use_join_token': true,
        });
        if (res['success'] == true) {
          final data = res['data'];
          if (data is Map && data['id'] != null) {
            // FormCreate tidak punya status/accept_responses â†’ persist via PATCH
            // supaya status closed/published & 'Terima respons' benar-benar tersimpan.
            if ((!publish && _formStatus != 'draft') || !_acceptResponses) {
              await ApiService.updateForm(data['id'].toString(), {
                'status': _formStatus,
                'accept_responses': _acceptResponses,
              });
            }
          }
        }
      }

      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftFormId = data['id'].toString();
          if (publish && _useJoinToken) {
            final tokenRes = await ApiService.regenerateJoinToken(
              _draftFormId!,
            );
            if (tokenRes['success'] != true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Token form gagal dibuat: ${tokenRes['message'] ?? 'terjadi kesalahan'}',
                  ),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
            }
          }

          // Read back the saved form so the editor reflects the canonical
          // server state, matching the web editor after an atomic PATCH.
          final saved = await ApiService.getForm(_draftFormId!);
          if (saved['success'] == true && saved['data'] is Map) {
            res = saved;
          }
        }
      } else if (_draftFormId != null && res['success'] != true) {
        // Inti perbaikan (parity web + lebih kuat): PATCH atomik di atas selalu
        // menggabungkan status/settings dengan questions. Dua kasus gagal total:
        //  (a) 409 — form sudah punya jawaban → backend menolak ganti soal
        //        (tapi SUDAH commit status/settings sebelum raise);
        //  (b) 422 — satu soal tidak valid → Pydantic menolak SELURUH request
        //        termasuk perubahan status.
        // Agar Published→Closed (dan judul/pengaturan) SELALU tersimpan walau
        // soal terkunci/invalid, kirim ulang PATCH TANPA questions (endpoint
        // yang sama — tidak ada endpoint baru). Soal yang gagal disimpan
        // dilaporkan jujur via flag, bukan dianggap sukses.
        final msgLower =
            res['message']?.toString().toLowerCase() ?? '';
        final isLocked = msgLower.contains('sudah punya jawaban');
        final isValidation = msgLower.contains('422') ||
            msgLower.contains('format data tidak valid') ||
            msgLower.contains('failed to update form');
        if (isLocked || isValidation) {
          final retry = await _saveStatusOnly(
            formId: _draftFormId!,
            titleHtml: titleHtml,
            descriptionHtml: descriptionHtml,
            settings: settings,
            originalError: res['message']?.toString() ??
                'Format soal tidak valid — status & pengaturan tetap tersimpan.',
          );
          if (retry['success'] == true) return retry;
          debugPrint(
              '[FormMaker] status-only retry gagal: ${retry['message']}');
        }
        // Parity web (FormBuilderPage.jsx): jika publish dan soal terkunci,
        // coba publish tanpa ubah soal agar link tetap bisa dibagikan.
        if (publish) {
          bool publishOk = false;
          Map<String, dynamic>? patchedData;
          try {
            final patched = await ApiService.updateForm(_draftFormId!, {
              'status': 'published',
            });
            if (patched['success'] == true) {
              publishOk = true;
              if (patched['data'] is Map) {
                patchedData = Map<String, dynamic>.from(patched['data'] as Map);
              }
            }
          } catch (_) {}
          if (!publishOk) {
            try {
              final pub = await ApiService.publishForm(_draftFormId!);
              if (pub['success'] == true) {
                publishOk = true;
                if (pub['data'] is Map) {
                  patchedData = Map<String, dynamic>.from(pub['data'] as Map);
                }
              }
            } catch (_) {}
          }
          if (publishOk) {
            return {
              'success': true,
              'data': patchedData ?? {'id': _draftFormId},
              'questionsLocked': true,
            };
          }
        }
      }
      return res;
    } finally {
      _markSavingDoneIfMounted();
    }
  }

  Future<void> _saveDraft() async {
    if (_builderState.isSaving) return;
    final res = await _saveForm(publish: false);
    if (!mounted || res == null) return;
    _handleSaveResult(res, isUpdate: false);
  }

  /// Simpan perubahan pada form yang sudah ada (mode edit) — parity web:
  /// tombol "Simpan"/"Perbarui" memanggil save biasa (publish:false) sehingga
  /// status pilihan user (termasuk Closed) dihormati, bukan dipaksa published.
  /// Setelah sukses penuh pada form published, QR di-refresh diam-diam
  /// (parity FormBuilderPage.jsx:364-368) tanpa dialog share yang mengganggu.
  Future<void> _saveChanges() async {
    if (_builderState.isSaving) return;
    final res = await _saveForm(publish: false);
    if (!mounted || res == null) return;
    _handleSaveResult(res, isUpdate: true);
    if (res['success'] == true &&
        res['questionsLocked'] != true &&
        res['questionsNotSaved'] != true &&
        _draftFormId != null &&
        _formStatus == 'published') {
      try {
        await ApiService.generateQrCode(_draftFormId!);
      } catch (_) {}
    }
  }

  /// Menampilkan hasil simpan secara jujur + sinkron editor ke server.
  /// [isUpdate] = true untuk mode edit (wording "diperbarui", parity tombol
  /// "Perbarui" pada web), false untuk form baru/draft.
  void _handleSaveResult(Map<String, dynamic> res, {required bool isUpdate}) {
    if (!mounted) return;
    if (res['success'] == true) {
      // Sinkronkan editor ke state kanonis server (penting setelah partial
      // save: soal yang ditolak backend tidak boleh tetap tampil seolah tersimpan).
      final data = res['data'];
      if (data is Map &&
          (res['questionsLocked'] == true ||
              res['questionsNotSaved'] == true)) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      if (res['questionsLocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengaturan tersimpan (termasuk status). Soal tidak diubah karena form sudah ada jawaban responden — duplikasi form dulu jika perlu.',
            ),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (res['questionsNotSaved'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status & pengaturan tersimpan. Tetapi soal gagal disimpan: ${res['questionsError'] ?? 'periksa kembali isian soal'}.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'Form berhasil diperbarui! Link siap dibagikan.'
                  : 'Draft berhasil disimpan — bisa dilanjutkan dari Dashboard / web',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      var msg = res['message']?.toString() ?? 'Unknown error';
      if (msg.toLowerCase().contains('sudah punya jawaban')) {
        // Parity web: judul/deskripsi/pengaturan tetap tersimpan (backend
        // commit sebelum 409), hanya ganti soal yang ditolak.
        msg =
            'Form sudah ada jawaban responden — judul & pengaturan tetap tersimpan, tapi soal tidak bisa diubah. Duplikasi form dulu jika perlu.';
      }
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isUpdate ? 'Gagal memperbarui form' : 'Gagal menyimpan draft'}: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan (isUpdate=$isUpdate): $msg');
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    _syncTitleFromPage();

    final titleHtml = _builderState.formTitle.trim().isNotEmpty
        ? _builderState.formTitle
        : 'Form Tanpa Judul';
    final descriptionHtml = _builderState.formDescription.trim();
    final questionsPayload = _builderState.buildApiPayload();

    _markSaving();

    final payload = {
      'title': titleHtml,
      'description': descriptionHtml,
      'banner_url': _builderState.bannerUrl,
      'questions': questionsPayload,
    };

    final String? targetId = _draftTemplateId ?? widget.initialTemplate?.id;
    final res = targetId != null
        ? await ApiService.updateTemplate(targetId, payload)
        : await ApiService.createTemplate(payload);
    if (!mounted) return;
    _markSavingDone();

    if (res['success'] == true) {
      if (_draftTemplateId == null && widget.initialTemplate?.id == null) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftTemplateId = data['id'].toString();
        }
      }
      Navigator.pop(
        context,
        FormMakerResult(
          template: FormTemplate(
            title: QuillHtml.htmlToPlainText(titleHtml),
            subtitle: 'Baru saja disimpan',
            id: _draftTemplateId ?? widget.initialTemplate?.id,
            questionsJson: questionsPayload,
          ),
        ),
      );
    } else {
      final msg = res['message']?.toString() ?? 'Unknown error';
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan template: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan template: $msg');
    }
  }

  void _publishForm() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (_builderState.formTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul formulir tidak boleh kosong')),
      );
      return;
    }

    // Cegah status Closed tertimpa diam-diam: tombol Publish selalu
    // menghasilkan status published (parity web). Minta konfirmasi dulu.
    if (_formStatus == 'closed') {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Status form Closed'),
          content: const Text(
            'Status di Setelan saat ini Closed. Tombol Publish akan mengubah '
            'status kembali menjadi Published agar link bisa dibagikan.\n\n'
            'Untuk menutup form, gunakan Simpan (status Closed tetap dipertahankan).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save_closed'),
              child: const Text('Simpan sebagai Closed'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'publish'),
              child: const Text('Tetap Publish'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null || choice == 'cancel') return;
      if (choice == 'save_closed') {
        await _saveDraft();
        return;
      }
      // 'publish' → lanjut ke alur publish normal di bawah.
    }

    final res = await _saveForm(publish: true);
    if (!mounted) return;
    if (res == null) return;
    if (res['success'] != true) {
      var msg = res['message']?.toString() ?? 'terjadi kesalahan';
      if (msg.toLowerCase().contains('sudah punya jawaban')) {
        msg =
            'Form sudah ada jawaban responden â€” hapus soal akan menghapus jawaban. Duplikasi form dulu jika perlu.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal publish form: $msg${_networkHint(msg)}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // Parity web: publish via fallback status-only (soal terkunci karena
    // sudah ada jawaban) — beri tahu user sebelum dialog share muncul.
    // Sinkronkan juga editor ke data server agar tidak tampilkan soal basi.
    if (res['questionsLocked'] == true && mounted) {
      final data = res['data'];
      if (data is Map) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Form berhasil dipublikasikan! (Soal tidak diubah karena sudah ada jawaban)',
          ),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 4),
        ),
      );
    }
    if (res['questionsNotSaved'] == true && mounted) {
      final data = res['data'];
      if (data is Map) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status & pengaturan tersimpan. Tetapi soal gagal disimpan: ${res['questionsError'] ?? 'periksa kembali isian soal'}.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }

    // FIX: jangan asal force-unwrap â€” kalau _draftFormId belum ke-set (mis. data
    // response tak punya id), ambil dari res supaya tidak null-crash.
    var formId = _draftFormId;
    if (formId == null) {
      final data = res['data'];
      if (data is Map && data['id'] != null) {
        _draftFormId = data['id'].toString();
        formId = _draftFormId;
      }
    }
    if (formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal publish form: tidak ada id form'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    _markSaving();

    final titlePlain = QuillHtml.htmlToPlainText(
      _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul',
    );

    // FIX Bug 17-18: createForm selalu draft, maka publish via endpoint khusus.
    // Pastikan benar-benar published (jangan lanjut generate QR kalau gagal).
    final pubRes = await ApiService.publishForm(formId);
    if (pubRes['success'] != true) {
      _markSavingDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal publish form: ${pubRes['message'] ?? 'terjadi kesalahan'}',
            ),
          ),
        );
      }
      return;
    }

    final qrRes = await ApiService.generateQrCode(formId);

    if (qrRes['success'] == true) {
      var shareLink = qrRes['data']['share_link'] as String;
      // Paksa link publik selalu menunjuk ke frontend yang dideploy (Vercel),
      // bukan localhost yang mungkin di-set di env backend.
      shareLink = ApiService.publicFormLink(shareLink);
      String qrUrl = qrRes['data']['qr_code_url'] as String;
      if (qrUrl.contains('localhost')) {
        final apiHost = Uri.parse(ApiService.baseUrl).host;
        qrUrl = qrUrl.replaceAll('localhost', apiHost);
      }
      if (mounted) _showShareDialog(shareLink, qrUrl, formId, titlePlain);
    } else {
      if (mounted) {
        _markSavingDoneIfMounted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate QR: ${qrRes['message']}')),
        );
      }
    }
  }
}
