// Para formateo y cálculo de fechas
import 'database_helper.dart'; // Para acceder a la BD

// Define los posibles estados del período de prueba
enum TrialState { active, expired, notStarted }

// Clase para contener el estado y los días restantes si está activo
class TrialStatus {
  final TrialState state;
  final int? daysRemaining; // Solo relevante si state es active

  TrialStatus(this.state, {this.daysRemaining});
}

class TrialService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const int trialDurationDays = 20;
  static const String trialStartDateKey = 'trial_start_date';

  Future<TrialStatus> checkTrialStatus() async {
    try {
      final startDateString = await _dbHelper.getSetting(trialStartDateKey);

      if (startDateString == null) {
        return TrialStatus(TrialState.notStarted);
      }

      final DateTime startDate = DateTime.parse(startDateString); 
      // Asegurarse que solo se considera la fecha, no la hora, para el cálculo
      final DateTime today = DateTime.now();
      final DateTime trialEndDate = startDate.add(Duration(days: trialDurationDays));

      // Normalizar las fechas a medianoche para comparación precisa de días
      final DateTime todayMidnight = DateTime(today.year, today.month, today.day);
      final DateTime endDateMidnight = DateTime(trialEndDate.year, trialEndDate.month, trialEndDate.day);

      if (todayMidnight.isBefore(endDateMidnight)) {
        // El trial está activo
        final difference = endDateMidnight.difference(todayMidnight);
        final daysRemaining = difference.inDays; 
        return TrialStatus(TrialState.active, daysRemaining: daysRemaining);
      } else {
        // El trial ha expirado (hoy es igual o posterior a la fecha de fin)
        return TrialStatus(TrialState.expired);
      }
    } catch (e) {
      // Considera usar un logger real aquí para registrar el error
      return TrialStatus(TrialState.notStarted); // Opcional: retornar expired en caso de error?
    }
  }
} 