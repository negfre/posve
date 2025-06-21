import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acuerdo de Servicio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acuerdo de Uso y Descargo de Responsabilidad',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Al utilizar esta aplicación (en adelante, "el software"), usted (en adelante, "el usuario") declara comprender y aceptar los siguientes términos y condiciones:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildTermPoint(
              context,
              '1. Software No Homologado y de Prueba:',
              'El usuario reconoce que este software es una herramienta de gestión de punto de venta (POS) para fines de control interno y/o de prueba. El software NO es un sistema de facturación homologado por el SENIAT (Servicio Nacional Integrado de Administración Aduanera y Tributaria) de acuerdo con la Providencia Administrativa N° SNAT/2024/000121 o cualquier otra normativa vigente o futura.',
            ),
            _buildTermPoint(
              context,
              '2. Uso No Recomendado para Fines Fiscales:',
              'No sugerimos, recomendamos ni respaldamos el uso de este software como sistema oficial para emitir facturas fiscales, recibos, u otros documentos con validez tributaria. Su propósito no es sustituir un sistema fiscal homologado.',
            ),
            _buildTermPoint(
              context,
              '3. Uso Bajo Responsabilidad del Usuario:',
              'Cualquier uso de este software para la emisión de documentos tributarios es de la entera y exclusiva responsabilidad del usuario.',
            ),
            _buildTermPoint(
              context,
              '4. Validez Fiscal:',
              'Es responsabilidad del usuario asegurarse de que los documentos generados cumplan con todos los requisitos legales y fiscales exigidos por el SENIAT y otras autoridades competentes en Venezuela. El desarrollador no garantiza que el formato o los datos generados sean válidos para propósitos fiscales.',
            ),
            _buildTermPoint(
              context,
              '5. Descargo de Responsabilidad:',
              'El desarrollador del software no asume ninguna responsabilidad, directa o indirecta, por sanciones, multas, o cualquier tipo de consecuencia legal, fiscal o financiera que pudiera derivarse del uso de este software. El usuario se compromete a mantener indemne al desarrollador de cualquier reclamación.',
            ),
            _buildTermPoint(
              context,
              '6. Recomendación Profesional:',
              'Se recomienda encarecidamente al usuario consultar con un asesor contable o tributario para garantizar el cumplimiento de todas las normativas fiscales vigentes en Venezuela.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermPoint(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
} 