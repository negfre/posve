# 🔐 Sistema de Licenciamiento POSVE

## 📋 Descripción

Este sistema permite activar la aplicación POSVE con una licencia válida generada específicamente para cada dispositivo. Solo tú (el desarrollador) puedes generar códigos de licencia válidos.

## 🔑 Clave Secreta

**IMPORTANTE**: La clave secreta es `"MI_CLAVE_SUPER_SECRETA_2024"`. 
- ✅ **GUÁRDALA SEGURA** - Solo tú debes conocerla
- ❌ **NO LA COMPARTAS** - Si alguien la conoce, puede generar licencias falsas
- 🔄 **Puedes cambiarla** - Editando la clave en `license_service.dart` y `license_generator.dart`

## 📱 Flujo de Activación

### Para el Cliente:
1. **Abrir la app** POSVE
2. **Ir a Configuración** → **Activar Licencia**
3. **Generar Token** - La app genera un token único de 24 caracteres
4. **Enviar el token** al desarrollador (WhatsApp, email, etc.)
5. **Recibir el código** de licencia del desarrollador
6. **Ingresar el código** en la app
7. **¡Listo!** La licencia se activa de por vida para ese dispositivo

### Para el Desarrollador (Tú):
1. **Recibir el token** del cliente
2. **Ejecutar el generador**: `dart run license_generator.dart`
3. **Ingresar el token** cuando te lo pida
4. **Recibir el código** de licencia generado
5. **Enviar el código** al cliente

## 🛠️ Herramientas

### 1. Generador de Licencias (`license_generator.dart`)
```bash
dart run license_generator.dart
```

**Uso:**
- Ejecuta el comando
- Ingresa el token del cliente
- Recibe el código de licencia válido
- Envías ese código al cliente

### 2. Script de Prueba (`test_license.dart`)
```bash
dart run test_license.dart
```

**Uso:**
- Prueba que el sistema funcione correctamente
- Verifica que solo códigos válidos sean aceptados
- Útil para debugging

## 🔒 Seguridad

### ¿Cómo funciona?
1. **Token de activación**: Generado por la app usando el ID único del dispositivo
2. **Código de licencia**: Hash SHA-256 del token + clave secreta
3. **Validación**: La app verifica que el código sea el hash correcto

### ¿Por qué es seguro?
- ✅ **Cada dispositivo tiene un token único**
- ✅ **Solo tú conoces la clave secreta**
- ✅ **Los códigos son específicos para cada token**
- ✅ **No se puede generar un código válido sin la clave**
- ✅ **La licencia es de por vida para ese dispositivo específico**

## ⚠️ Advertencias

### Para el Cliente:
- **Sin licencia activa**: Los productos se eliminan automáticamente cada 10 días
- **Advertencias diarias**: La app muestra alertas cada día sin licencia
- **Dispositivo específico**: La licencia solo funciona en el dispositivo donde se generó el token

### Para el Desarrollador:
- **Guarda la clave secreta**: Si la pierdes, no podrás generar más licencias
- **Backup del generador**: Guarda una copia del `license_generator.dart`
- **Registro de licencias**: Considera llevar un registro de tokens y códigos generados

## 🚀 Instalación y Uso

### Requisitos:
- Dart SDK instalado
- Dependencia `crypto` (ya incluida en `pubspec.yaml`)

### Pasos:
1. **Clonar/descargar** el proyecto
2. **Instalar dependencias**: `flutter pub get`
3. **Usar el generador**: `dart run license_generator.dart`

## 📞 Soporte

Si tienes problemas:
1. **Verifica la clave secreta** en ambos archivos
2. **Ejecuta el script de prueba**: `dart run test_license.dart`
3. **Revisa los logs** de la aplicación
4. **Contacta al desarrollador** si persisten los problemas

## 🔄 Actualizaciones

Para cambiar la clave secreta:
1. **Editar** `lib/src/services/license_service.dart` (línea con `secretKey`)
2. **Editar** `license_generator.dart` (línea con `secretKey`)
3. **Recompilar** la aplicación
4. **Notificar** a los clientes que necesitarán nueva licencia

---

**¡El sistema está listo para usar! 🎉** 