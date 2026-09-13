import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../models/project.dart';

class MockData {
  static final List<Project> dashboardProjects = [
    Project(title: "Formax", status: "Active", icon: Icons.edit),
    Project(title: "CMS design stuff", status: "Draft", icon: Icons.edit),
    Project(
      title: "CMS design stuff - Page 1",
      status: "Archived",
      icon: Icons.play_arrow,
    ),
    Project(title: "Website SMK 10", status: "Active", icon: Icons.edit),
  ];

  // Template bawaan — mirror dari web/backend (scripts/seed.py).
  // [0] Empty Form dipertahankan apa adanya (jangan dihapus).
  // [1..] disamakan dengan 2 template sistem web: Attendance Form & Exam Form.
  // Data ini hanya untuk preview lokal; sumber utama tetap
  // backend via GET /templates (is_system=true).
  static final List<FormTemplate> builtInTemplates = [
    // ── [0] DIBIARKAN — Empty Form ──────────────────────────────────
    FormTemplate(
      title: "Empty Form",
      subtitle: "empty description",
      questionsJson: [],
    ),
    // ── [1] = Web "Attendance Form" ─────────────────────────────────
    // backend: description "Form absensi kehadiran", 3 questions.
    FormTemplate(
      title: "Attendance Form",
      subtitle: "Form absensi kehadiran",
      isSystem: true,
      questionsJson: [
        {
          'type': 'text',
          'label': 'Nama Lengkap',
          'placeholder': '',
          'is_required': true,
          'order_index': 0,
          'settings': {},
          'options': [],
        },
        {
          'type': 'text',
          'label': 'NIM / NIS',
          'placeholder': '',
          'is_required': true,
          'order_index': 1,
          'settings': {},
          'options': [],
        },
        {
          'type': 'single_choice',
          'label': 'Status Kehadiran',
          'placeholder': '',
          'is_required': true,
          'order_index': 2,
          'settings': {},
          'options': [
            {
              'label': 'Hadir',
              'value': 'hadir',
              'order_index': 0,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Izin',
              'value': 'izin',
              'order_index': 1,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Sakit',
              'value': 'sakit',
              'order_index': 2,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Alpha',
              'value': 'alpha',
              'order_index': 3,
              'is_correct': false,
              'is_other': false,
            },
          ],
        },
      ],
    ),
    // ── [2] = Web "Exam Form" ───────────────────────────────────────
    // backend: description "Form ujian dengan berbagai tipe soal", 3 questions.
    FormTemplate(
      title: "Exam Form",
      subtitle: "Form ujian dengan berbagai tipe soal",
      isSystem: true,
      questionsJson: [
        {
          'type': 'text',
          'label': 'Nama Peserta',
          'placeholder': '',
          'is_required': true,
          'order_index': 0,
          'settings': {},
          'options': [],
        },
        {
          'type': 'single_choice',
          'label': 'Soal 1 (contoh pilihan ganda)',
          'placeholder': '',
          'is_required': true,
          'order_index': 1,
          'settings': {},
          'options': [
            {
              'label': 'A',
              'value': 'A',
              'order_index': 0,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'B',
              'value': 'B',
              'order_index': 1,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'C',
              'value': 'C',
              'order_index': 2,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'D',
              'value': 'D',
              'order_index': 3,
              'is_correct': false,
              'is_other': false,
            },
          ],
        },
        {
          'type': 'file_upload',
          'label': 'Upload Lembar Jawaban (jika ada)',
          'placeholder': '',
          'is_required': false,
          'order_index': 2,
          'settings': {},
          'options': [],
        },
      ],
    ),
  ];

  static final List<Map<String, dynamic>> historyItems = [
    {"title": "Quizz", "icon": Icons.insert_drive_file_outlined},
    {"title": "Ujian", "icon": Icons.assignment_outlined},
    {"title": "Angket Classmeet", "icon": Icons.insert_chart_outlined},
  ];

  static List<Map<String, dynamic>> getMockResponses(String title) {
    if (title == "Quizz") {
      return [
        {
          "name": "budi santoso",
          "email": "budi.santoso@example.com",
          "time": "Hari ini, 08:30 WIB",
          "isAuto": true,
        },
        {
          "name": "citra lestari",
          "email": "citra.lestari@example.com",
          "time": "Hari ini, 08:45 WIB",
          "isAuto": false,
        },
        {
          "name": "dani ramadhan",
          "email": "dani.ramadhan@example.com",
          "time": "Hari ini, 09:12 WIB",
          "isAuto": true,
        },
      ];
    } else if (title == "Ujian") {
      return [
        {
          "name": "andi pratama",
          "email": "andi.pratama@example.com",
          "time": "Hari ini, 09:42 WIB",
          "isAuto": true,
        },
        {
          "name": "budi santoso",
          "email": "budi.santoso@example.com",
          "time": "Kemarin, 15:20 WIB",
          "isAuto": false,
        },
        {
          "name": "citra lestar",
          "email": "citra.lestar@example.com",
          "time": "12 Okt 2023, 11:05 WIB",
          "isAuto": true,
        },
      ];
    } else {
      return [
        {
          "name": "eko saputra",
          "email": "eko.saputra@example.com",
          "time": "2 hari yang lalu",
          "isAuto": false,
        },
        {
          "name": "fina melani",
          "email": "fina.melani@example.com",
          "time": "2 hari yang lalu",
          "isAuto": false,
        },
      ];
    }
  }

  static String getTotalResponses(String title) {
    if (title == "Quizz") return "120";
    if (title == "Ujian") return "342";
    return "85";
  }

  static List<Map<String, String>> getAnswers(String formTitle, String name) {
    if (formTitle == "Quizz") {
      if (name.toLowerCase().contains("budi")) {
        return [
          {"question": "Mata pelajaran favorit?", "answer": "Matematika"},
          {"question": "Berapa nilai rata-rata?", "answer": "85"},
          {
            "question": "Kesan selama belajar?",
            "answer":
                "Sangat menyenangkan, guru-guru yang mengajar sangat kompeten dan membantu saya memahami materi.",
          },
        ];
      } else if (name.toLowerCase().contains("citra")) {
        return [
          {"question": "Mata pelajaran favorit?", "answer": "Bahasa Inggris"},
          {"question": "Berapa nilai rata-rata?", "answer": "92"},
          {
            "question": "Kesan selama belajar?",
            "answer":
                "Metode pengajaran yang interaktif membuat saya lebih mudah memahami pelajaran.",
          },
        ];
      } else {
        return [
          {"question": "Mata pelajaran favorit?", "answer": "Fisika"},
          {"question": "Berapa nilai rata-rata?", "answer": "78"},
          {
            "question": "Kesan selama belajar?",
            "answer":
                "Cukup menantang tapi seru, terutama saat praktikum di laboratorium.",
          },
        ];
      }
    } else if (formTitle == "Ujian") {
      if (name.toLowerCase().contains("andi")) {
        return [
          {"question": "Departemen Anda?", "answer": "Marketing"},
          {"question": "Tingkat Kepuasan?", "answer": "Puas"},
          {
            "question": "Masukan untuk tim?",
            "answer":
                "Aplikasi sangat mudah digunakan dan sangat membantu pekerjaan saya sehari-hari.",
          },
        ];
      } else if (name.toLowerCase().contains("budi")) {
        return [
          {"question": "Departemen Anda?", "answer": "Engineering"},
          {"question": "Tingkat Kepuasan?", "answer": "Sangat Puas"},
          {
            "question": "Masukan untuk tim?",
            "answer":
                "Fitur-fitur sudah lengkap, hanya perlu peningkatan di bagian performa loading.",
          },
        ];
      } else {
        return [
          {"question": "Departemen Anda?", "answer": "HR"},
          {"question": "Tingkat Kepuasan?", "answer": "Cukup Puas"},
          {
            "question": "Masukan untuk tim?",
            "answer":
                "Semoga kedepannya bisa ada fitur integrasi dengan tools HR lainnya.",
          },
        ];
      }
    } else {
      // Angket Classmeet
      if (name.toLowerCase().contains("eko")) {
        return [
          {"question": "Acara mana yang paling kamu suka?", "answer": "Futsal"},
          {"question": "Rating keseluruhan acara?", "answer": "4 dari 5"},
          {
            "question": "Saran untuk acara selanjutnya?",
            "answer":
                "Tambahkan lebih banyak games dan doorprize agar lebih seru.",
          },
        ];
      } else {
        return [
          {
            "question": "Acara mana yang paling kamu suka?",
            "answer": "Lomba Menyanyi",
          },
          {"question": "Rating keseluruhan acara?", "answer": "5 dari 5"},
          {
            "question": "Saran untuk acara selanjutnya?",
            "answer":
                "Sudah sangat bagus! Semoga tahun depan lebih meriah lagi.",
          },
        ];
      }
    }
  }
}
