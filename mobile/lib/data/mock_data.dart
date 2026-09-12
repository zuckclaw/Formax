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

  // BUG FIX #3: built-in templates sekarang punya struktur questionsJson
  // agar ketika diklik tidak fallback ke "Opsi 1". Data ini hanya untuk preview lokal;
  // template sistem sebenarnya sebaiknya diambil dari backend via GET /templates (is_system=true).
  static final List<FormTemplate> builtInTemplates = [
    FormTemplate(
      title: "Empty Form",
      subtitle: "empty description",
      questionsJson: [],
    ),
    FormTemplate(
      title: "Ujian",
      subtitle: "empty description",
      isSystem: true,
      questionsJson: [
        {
          'type': 'single_choice',
          'label': 'Departemen Anda?',
          'placeholder': '',
          'is_required': true,
          'order_index': 0,
          'settings': {},
          'options': [
            {
              'label': 'Marketing',
              'value': 'Marketing',
              'order_index': 0,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Engineering',
              'value': 'Engineering',
              'order_index': 1,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'HR',
              'value': 'HR',
              'order_index': 2,
              'is_correct': false,
              'is_other': false,
            },
          ],
        },
        {
          'type': 'single_choice',
          'label': 'Tingkat Kepuasan?',
          'placeholder': '',
          'is_required': false,
          'order_index': 1,
          'settings': {},
          'options': [
            {
              'label': 'Sangat Puas',
              'value': 'Sangat Puas',
              'order_index': 0,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Puas',
              'value': 'Puas',
              'order_index': 1,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Cukup Puas',
              'value': 'Cukup Puas',
              'order_index': 2,
              'is_correct': false,
              'is_other': false,
            },
          ],
        },
        {
          'type': 'paragraph',
          'label': 'Masukan untuk tim?',
          'placeholder': 'Tulis masukan Anda...',
          'is_required': false,
          'order_index': 2,
          'settings': {},
          'options': [],
        },
      ],
    ),
    FormTemplate(
      title: "Angket Classmeet",
      subtitle: "empty description",
      isSystem: true,
      questionsJson: [
        {
          'type': 'single_choice',
          'label': 'Acara mana yang paling kamu suka?',
          'placeholder': '',
          'is_required': true,
          'order_index': 0,
          'settings': {},
          'options': [
            {
              'label': 'Futsal',
              'value': 'Futsal',
              'order_index': 0,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Lomba Menyanyi',
              'value': 'Lomba Menyanyi',
              'order_index': 1,
              'is_correct': false,
              'is_other': false,
            },
            {
              'label': 'Bazaar',
              'value': 'Bazaar',
              'order_index': 2,
              'is_correct': false,
              'is_other': false,
            },
          ],
        },
        {
          'type': 'rating',
          'label': 'Rating keseluruhan acara?',
          'placeholder': '',
          'is_required': false,
          'order_index': 1,
          'settings': {'rating_count': 5, 'rating_icon': 'star'},
          'options': [],
        },
        {
          'type': 'paragraph',
          'label': 'Saran untuk acara selanjutnya?',
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
