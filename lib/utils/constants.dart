// lib/utils/constants.dart

/// Konstanta untuk informasi perusahaan
class CompanyInfo {
  static const String name = 'PT PINKYSAN';
  static const String address = 'Jl. Contoh No. 123, Jakarta';
  static const String phone = '+62 21 1234567';
  static const String email = 'info@perusahaan.com';

  // Untuk kebutuhan PDF
  static const String invoiceTitle = 'Invoice Bonus Karyawan';
  static const String warningLetterTitle = 'Surat Peringatan';
  static const String hrDivision = 'Divisi Human Resources';
}

/// Konstanta untuk konfigurasi bonus
class BonusConfig {
  static const int minimumAmount = 50000; // Rp 50.000
  static const String minimumAmountFormatted = 'Rp 50.000';
}

/// Konstanta untuk status
class TargetStatus {
  static const String active = 'active';
  static const String submitted = 'submitted';
  static const String bonusPending = 'bonus_pending';
  static const String bonusApproved = 'bonus_approved';
  static const String evaluated = 'evaluated';
  static const String paid = 'paid';
}

class SubmissionStatus {
  static const String submitted = 'submitted';
  static const String evaluated = 'evaluated';
  static const String bonusPending = 'bonus_pending';
  static const String bonusApproved = 'bonus_approved';
  static const String paid = 'paid';
}

class BonusStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String paid = 'paid';
  static const String rejected = 'rejected';
}

/// Konstanta untuk warning letter levels
class WarningLevel {
  static const String sp1 = 'SP1';
  static const String sp2 = 'SP2';
  static const String sp3 = 'SP3';
}
