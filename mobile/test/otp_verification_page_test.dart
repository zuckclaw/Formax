import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form4x/pages/otp_verification_page.dart';
import 'package:form4x/pages/login_page.dart';

void main() {
  testWidgets('OtpVerificationPage renders exactly 6 boxes and dashes by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtpVerificationPage(
          email: 'user@example.com',
          length: 6,
        ),
      ),
    );

    expect(find.text('Verifikasi OTP'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(
      find.text('Kode 6 digit telah dikirim ke email kamu. Masukkan di bawah untuk lanjut.'),
      findsOneWidget,
    );
    expect(find.text('Tempel kode dari email — otomatis terisi'), findsOneWidget);
    expect(find.text('Belum dapat kode?'), findsOneWidget);
    expect(find.text('Kirim ulang'), findsOneWidget);
    expect(find.text('Konfirmasi & Buat Akun'), findsOneWidget);
    expect(find.text('Kode berlaku 5 menit · jaga kerahasiaan kode'), findsOneWidget);
  });

  testWidgets('OtpVerificationPage dynamically adjusts boxes and subtitle for 4 digits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtpVerificationPage(
          email: 'custom@example.com',
          length: 4,
          buttonText: 'Verifikasi Kode',
        ),
      ),
    );

    expect(
      find.text('Kode 4 digit telah dikirim ke email kamu. Masukkan di bawah untuk lanjut.'),
      findsOneWidget,
    );
    expect(find.text('Verifikasi Kode'), findsOneWidget);
  });

  testWidgets('OtpVerificationPage enters partial digits and updates visual boxes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtpVerificationPage(
          email: 'test@example.com',
          length: 4,
        ),
      ),
    );

    // Enter 2 digits out of 4 (so it doesn't auto-pop yet)
    await tester.enterText(find.byType(TextField), '72');
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('OtpVerificationPage auto-submits when all digits are filled', (
    WidgetTester tester,
  ) async {
    String? submittedOtp;

    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationPage(
          email: 'test@example.com',
          length: 4,
          onVerify: (otp) async {
            submittedOtp = otp;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '7729');
    await tester.pumpAndSettle();

    expect(submittedOtp, equals('7729'));
  });

  testWidgets('ForgotPasswordPage renders with input email and Kirim Kode OTP button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForgotPasswordPage(initialEmail: 'bonic80752@meonvr.com'),
      ),
    );

    expect(find.text('Lupa Password'), findsOneWidget);
    expect(find.text('bonic80752@meonvr.com'), findsOneWidget);
    expect(find.text('Kirim Kode OTP'), findsOneWidget);
    expect(find.text('Ingat password? Kembali ke Login'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage renders with password fields and button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordPage(
          email: 'bonic80752@meonvr.com',
          otp: '772964',
        ),
      ),
    );

    expect(find.text('Password Baru'), findsWidgets);
    expect(find.text('bonic80752@meonvr.com'), findsOneWidget);
    expect(find.text('Simpan & Masuk'), findsOneWidget);
  });
}
