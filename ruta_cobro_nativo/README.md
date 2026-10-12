# RutaCobro RD – Flutter nativo (completo)

Reescritura **nativa** en Flutter/Dart. No es WebView.

## Funciones incluidas

### Auth y datos
- Google Sign-In (Firebase Auth)
- Firestore: `datos/{uid}/clientes|prestamos|pagos`
- Perfil de usuario + código RC-XXXX
- Bloqueo por membresía (`paidUntil` / `exemptUntil`) → solo lectura

### Clientes
- Crear, editar, eliminar (con préstamos y pagos)
- Buscar por nombre / teléfono / referencia
- Ficha con lista de préstamos

### Préstamos
- Tipo **rédito** (fee en RD$ o %)
- Tipo **cuotas** (% total + nº cuotas)
- Frecuencias: diario, semanal (día de la semana), quincenal, mensual, personalizado (días del mes)
- Renovar préstamo manteniendo próximo cobro
- Estados: Al día / Vence hoy / Atrasado (con días) / Liquidado

### Cobros (motor portado del JS)
- Rédito: pago de interés + abono a capital (recalcula fee)
- Cuotas: cuota normal / pago de rédito / avance a préstamo
- Avance de fechas con `stepR`, `stepC`, `stepCR`, `stepA`
- Recibo + envío por WhatsApp

### Hoy
- Lista de vencidos y del día
- KPIs de cantidad y monto estimado

### Historial
- Filtros: hoy, semana, mes, año, todo, rango de fechas
- Buscar por cliente
- Total del período

### Resumen
- Cobrado / interés / capital del período
- Cartera activa, atrasados, saldo en calle

### Ajustes
- Perfil, código, estado de membresía, cerrar sesión

## Compilar

### GitHub Actions
Sube la carpeta a GitHub → Actions → Build Android APK → descarga el APK.

### Local
```bash
flutter pub get
flutter build apk --release
```

## Firebase Android
1. Firebase Console → añade app Android `com.rutacobro.rd.prueba`
2. Coloca `google-services.json` en `android/app/`
3. Activa Google Sign-In

Package: `com.rutacobro.rd.prueba` · minSdk 23
