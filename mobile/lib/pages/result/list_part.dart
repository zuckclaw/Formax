// Builder daftar & status ResultPage — kartu token, filter, daftar + tile
// responden, pil status, detail jawaban, empty/error state, format waktu.
// Dipindah verbatim dari `lib/pages/result_page.dart` (Tahap 5c) tanpa
// perubahan logika. File ini adalah `part` dari library yang sama sehingga
// akses state/helper privat tetap sah; call-site tidak berubah.
// Penyesuaian wajib: 1 situs setState (chip filter) didelegasikan ke helper
// State._applyStatusFilter (extension dilarang memanggil protected member
// langsung); urutan + isi statement identik.
// Extension privat (nama underscore) agar tidak bocor ke public API.
part of '../result_page.dart';

extension _ResultList on _ResultPageState {
  Widget _buildJoinTokenCard(String token) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security,
                  size: 18,
                  color: Color(0xFF4338CA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Token akses form',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF312E81),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gunakan token untuk membuka akses form',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu token',
                icon: const Icon(Icons.more_vert, color: Color(0xFF312E81)),
                onSelected: (value) {
                  if (value == 'copy') {
                    _copyJoinToken(token);
                  } else if (value == 'regen') {
                    _regenerateJoinToken();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'copy', child: Text('Salin token')),
                  PopupMenuItem(
                    value: 'regen',
                    child: Text('Generate ulang token'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8C5FF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    token,
                    style: const TextStyle(
                      letterSpacing: 1.2,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _copyJoinToken(token),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC7D2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.copy_all_rounded,
                      size: 18,
                      color: Color(0xFF312E81),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, String value) {
      final selected = _statusFilter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        selectedColor: const Color(0xFF059669),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: selected
              ? const Color(0xFF059669)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        onSelected: (_) => _applyStatusFilter(value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Semua Status', 'semua'),
        chip('Selesai', 'selesai'),
        chip('Proses', 'proses'),
        chip('Curang', 'curang'),
      ],
    );
  }

  Widget _buildRespondentList(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: submissions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final sub = submissions[index];
          return _buildRespondentTile(sub, gradeMap, labels);
        },
      ),
    );
  }

  Widget _buildRespondentTile(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    final initial = sub.respondentName.isNotEmpty
        ? sub.respondentName[0].toUpperCase()
        : '?';
    final timeStr = sub.submittedAt != null
        ? _formatTime(sub.submittedAt!)
        : 'Belum dikirim';
    final score = _scoreOf(sub, gradeMap);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailResponsePage(
              name: sub.respondentName,
              email: sub.respondentEmail,
              time: timeStr,
              isAuto: sub.isAutoSubmitted,
              isCheated: sub.isCheated,
              scoreText: score != null ? '$score/100' : null,
              formTitle: widget.formTitle,
              answers: _buildAnswerDetails(sub, gradeMap, labels),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1E40AF),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.respondentName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.respondentEmail == '-' ? 'Anonim' : sub.respondentEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.isAutoSubmitted
                        ? '$timeStr • dikirim otomatis'
                        : timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusPill(sub),
            const SizedBox(width: 8),
            if (score != null)
              Text(
                '$score/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: score >= 70
                      ? const Color(0xFF059669)
                      : (score >= 40
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626)),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(SubmissionModel sub) {
    final (String label, Color color, Color bg) = sub.isCheated
        ? ('Curang', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
        : sub.submittedAt != null
        ? ('Selesai', const Color(0xFF059669), const Color(0xFFD1FAE5))
        : ('Proses', const Color(0xFFD97706), const Color(0xFFFEF3C7));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildAnswerDetails(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return sub.answers.map((a) {
      final keys = gradeMap[a.questionId];
      final graded = keys != null && keys.isNotEmpty;
      bool? isCorrect;
      if (graded) isCorrect = _answerMatches(a, keys);
      return {
        'question': (labels[a.questionId]?.isNotEmpty ?? false)
            ? labels[a.questionId]
            : a.questionLabel,
        'answer': _cleanText(a.display),
        'isCorrect': isCorrect,
        'correctAnswer': (graded && keys.isNotEmpty)
            ? _cleanText(keys.join(', '))
            : null,
        'fileUrl': a.fileUrl,
      };
    }).toList();
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            _statusFilter == 'semua'
                ? 'Belum ada respons'
                : 'Tidak ada respons dengan status ini',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            'Bagikan link form untuk mulai menerima jawaban.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Tidak dapat memuat respons',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reload, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
