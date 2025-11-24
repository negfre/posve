# Análisis del Sistema de Licenciamiento y Adaptación a Inventario

## 📋 Análisis del Sistema de Licenciamiento

### Funcionamiento Actual

El sistema de licenciamiento de POSVE funciona de la siguiente manera:

#### 1. **Generación del Device ID**
- Se genera un ID único del dispositivo basado en:
  - **Android**: ANDROID_ID, modelo, fabricante, versión SDK, fingerprint, timestamp de instalación
  - **iOS**: identifierForVendor, modelo, versión del sistema, arquitectura, timestamp de instalación
- El ID se hashea con SHA-256 y se toma los últimos 20 caracteres
- Se almacena de forma persistente en SharedPreferences

#### 2. **Token de Activación**
- Se genera un token fijo basado en el Device ID: `POSVE_ACTIVATION_{deviceId}`
- El token se hashea con SHA-256 y se toma los primeros 24 caracteres

#### 3. **Validación de Licencia**
- Se usa una clave secreta: `"MI_CLAVE_SUPER_SECRETA_2024"`
- Se genera un hash combinando: `activationToken + secretKey`
- El código de licencia debe coincidir con los últimos 20 caracteres del hash

#### 4. **Restricciones sin Licencia**
- **Advertencias**: Se muestran cada 1 día si no hay licencia activa
- **Limpieza de productos**: Se eliminan todos los productos cada 10 días sin licencia
- **Verificación**: Al iniciar la app se verifica el estado de la licencia

#### 5. **Almacenamiento**
- La licencia se guarda en SharedPreferences como JSON
- Incluye: deviceId, activationToken, licenseKey, activatedAt, isActive, deviceInfo

### Ventajas del Sistema Actual
✅ Licencia vinculada al dispositivo (dificulta la piratería)
✅ Sistema de advertencias progresivo
✅ Limpieza automática de datos sin licencia
✅ Validación criptográfica segura

### Consideraciones para Play Store
⚠️ **IMPORTANTE**: Este sistema puede violar las políticas de Google Play Store:
- Google prohíbe aplicaciones que eliminen datos del usuario sin su consentimiento explícito
- La eliminación automática de productos cada 10 días puede considerarse comportamiento malicioso
- Se recomienda cambiar a un sistema de "modo de prueba" con limitaciones de funcionalidad en lugar de eliminación de datos

### Opciones de Mejora para Play Store

#### Opción 1: Modo de Prueba (Recomendado)
- Sin licencia: Funcionalidad limitada (máximo 50 productos, sin exportar reportes)
- Con licencia: Funcionalidad completa
- **NO eliminar datos del usuario**

#### Opción 2: Suscripción In-App
- Usar Google Play Billing para suscripciones
- Más compatible con políticas de Play Store
- Permite gestión automática de renovaciones

#### Opción 3: Licencia de Prueba Temporal
- 30 días de prueba completa
- Después: modo limitado (no eliminación de datos)

---

## 🎯 Adaptación de la Interfaz a Enfoque de Inventario

### Cambios Propuestos

#### 1. **Home Page - Priorizar Inventario**

**Cambios en el Dashboard:**
- **Métricas principales** (arriba):
  1. Total de Productos
  2. Productos con Stock Bajo
  3. Productos Sin Stock
  4. Valor Total del Inventario (USD/VES)

- **Métricas secundarias** (abajo):
  5. Ventas del Mes
  6. Compras del Mes
  7. Movimientos Recientes
  8. Tasa de Cambio

**Accesos Rápidos:**
- Nueva prioridad: Inventario → Productos → Ventas → Compras
- Botones destacados:
  1. **Gestionar Inventario** (principal)
  2. Agregar Producto
  3. Ver Movimientos
  4. Registrar Compra
  5. Nueva Venta

**Secciones reorganizadas:**
1. **Inventario** (primera sección)
   - Productos
   - Categorías
   - Movimientos
   - Proveedores

2. **Operaciones** (segunda sección)
   - Ventas
   - Compras
   - Gastos

3. **Reportes y Configuración** (tercera sección)
   - Reportes
   - Configuración
   - Administración

#### 2. **Títulos y Textos**
- Cambiar "POSVE - Dashboard" → "POSVE - Gestión de Inventario"
- "Bienvenido a tu sistema de gestión" → "Controla tu inventario de forma eficiente"
- Enfatizar términos relacionados con inventario

#### 3. **Widgets de Métricas**
- Agregar widget de "Valor Total del Inventario"
- Destacar alertas de stock bajo
- Mostrar gráfico de productos por categoría

#### 4. **Navegación**
- El menú lateral prioriza Inventario
- El drawer muestra primero opciones de inventario

### Funcionalidades que se MANTIENEN
✅ Todas las funcionalidades existentes se mantienen
✅ Ventas, compras, gastos, reportes siguen disponibles
✅ Solo se reorganiza la interfaz para priorizar inventario

---

## 📝 Plan de Implementación

### Fase 1: Análisis y Documentación ✅
- [x] Analizar sistema de licenciamiento
- [x] Documentar funcionamiento
- [x] Identificar cambios necesarios

### Fase 2: Adaptación de Interfaz
- [ ] Modificar `home_page.dart` para priorizar inventario
- [ ] Reorganizar métricas
- [ ] Actualizar textos y títulos
- [ ] Reorganizar accesos rápidos
- [ ] Actualizar drawer/menú lateral

### Fase 3: Mejoras Adicionales (Opcional)
- [ ] Agregar widget de valor total de inventario
- [ ] Mejorar visualización de alertas de stock
- [ ] Agregar gráficos de inventario

### Fase 4: Preparación para Play Store
- [ ] Modificar sistema de licenciamiento (modo prueba en lugar de eliminación)
- [ ] Configurar firma de aplicación
- [ ] Generar AAB para Play Store
- [ ] Preparar capturas y descripción

---

## ⚠️ Advertencias Importantes

1. **Sistema de Licenciamiento**: El sistema actual que elimina productos puede violar políticas de Play Store. Se recomienda cambiar a modo de prueba con limitaciones.

2. **Firma de Aplicación**: Necesitas configurar un keystore para firmar la aplicación antes de subirla a Play Store.

3. **Versión**: Actualmente está en `1.0.0+1`, considera incrementar antes de publicar.

4. **Permisos**: Revisa los permisos en AndroidManifest.xml y elimina los innecesarios.

---

## 🚀 Próximos Pasos Recomendados

1. **Inmediato**: Adaptar interfaz a enfoque de inventario
2. **Corto plazo**: Modificar sistema de licenciamiento para Play Store
3. **Mediano plazo**: Configurar firma y generar AAB
4. **Largo plazo**: Publicar en Play Store



