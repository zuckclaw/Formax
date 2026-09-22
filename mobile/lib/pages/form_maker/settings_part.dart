// Helper setelan & timer FormMakerPage — muat setelan draft, parse tanggal,
// picker tanggal timer, format, durasi, hint jaringan, sinkron judul.
// Dipindah verbatim dari `lib/pages/formmakerpage.dart` (Tahap 6b) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses ke state privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 1 situs setState (_pickTimerDate) didelegasikan ke
// helper State._applyTimerDate (extension dilarang memanggil protected
// member langsung); urutan + isi statement identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../formmakerpage.dart';

extension _FormMakerSettings on _FormMakerPageState {
  // Muat setelan form dari draft (GET /forms/{id}) supaya panel Setelan
  // menampilkan status & limit yang benar saat lanjutkan draft.
  void _applyFormSettings(Map<String, dynamic> map) {
    _formStatus = map['status']?.toString() ?? 'draft';
    _acceptResponses = map['accept_responses'] as bool? ?? true;
    _requireFullscreen = map['require_fullscreen'] as bool? ?? false;
    _correctAnswers = map['allow_see_result'] as bool? ?? false;
    _revealAnswers =
        _correctAnswers && (map['reveal_answers'] as bool? ?? false);
    _useJoinToken = map['join_token']?.toString().isNotEmpty ?? false;
    _shuffleQuestions = map['shuffle_questions'] as bool? ?? false;
    _shuffleOptions = map['shuffle_options'] as bool? ?? false;
    // Tema: baca apa adanya (null = default), tandai belum disentuh agar
    // save berikutnya tidak menimpa tema yang dipasang dari web.
    _themeAccent = normalizeFormAccent(map['theme']);
    _themeTouched = false;
    _startDate = _parseDate(map['start_date']);
    _endDate = _parseDate(map['end_date']);
    final maxSub = map['max_submissions'];
    if (maxSub is int) {
      if (maxSub == 1) {
        _submissionLimit = 'once';
      } else if (maxSub == 0) {
        _submissionLimit = 'unlimited';
      } else {
        _submissionLimit = 'custom';
        _customSubLimitCtrl.text = '$maxSub';
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _pickTimerDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime.now(),
    );
    if (!mounted || pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (!mounted || pickedTime == null) return;
    final value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    _applyTimerDate(start, value);
  }

  void _clearTimerDate({required bool start}) {
    _applyTimerDate(start, null);
  }

  String _formatTimerDate(DateTime? value) {
    if (value == null) return 'Pilih tanggal dan waktu';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }



  String _networkHint(String msg) {
    return msg.contains('SocketException') ||
            msg.contains('Failed host') ||
            msg.contains('Connection refused') ||
            msg.contains('No token')
        ? '\n\nCek: backend jalan di ${ApiService.baseUrl}?\nEmulator: 10.0.2.2:8000 | HP fisik: adb reverse tcp:8000 tcp:8000 + --dart-define=API_URL=http://127.0.0.1:8000'
        : '';
  }

  void _syncTitleFromPage() {
    if (_builderState.pages.isNotEmpty) {
      _builderState.formTitle = _builderState.pages[0].title;
      _builderState.formDescription = _builderState.pages[0].description;
    }
  }
}
