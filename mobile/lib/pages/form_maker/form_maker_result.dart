// Hasil navigasi FormMakerPage — dikembalikan via Navigator.pop.
// Dipindah verbatim dari `lib/pages/formmakerpage.dart` (Tahap 6a) tanpa
// perubahan apa pun. Class publik murni (tanpa dependensi privat) sehingga
// menjadi library biasa; `formmakerpage.dart` me-re-export agar 6+ file
// konsumen (draft/history/home/template_card/search_results) tidak berubah.
import '../../models/form_template.dart';

class FormMakerResult {
  final String? draftFormId;
  final String? draftFormTitle;
  final FormTemplate? template;

  const FormMakerResult({this.draftFormId, this.draftFormTitle, this.template});

  bool get savedDraft => draftFormId != null && draftFormId!.isNotEmpty;
  bool get savedTemplate => template != null;
}
