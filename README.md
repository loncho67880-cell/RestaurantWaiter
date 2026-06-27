# Restaurant Waiter

Aplicación Flutter orientada al **mesero** dentro de la plataforma de restaurantes. Permite gestionar reservas activas, confirmar pedidos, tomar órdenes manuales, marcar mesas listas para pagar y (para administradores) configurar el layout de mesas con códigos QR.

## Características

- **Autenticación** con Google Sign-In vinculada al restaurante configurado.
- **Selección de sucursal** al iniciar sesión.
- **Reservas activas**: confirmar llegada del cliente, revisar y editar pre-órdenes, enviar pedidos a cocina y marcar mesas como listas para pagar.
- **Pedido manual**: crear órdenes directamente desde el menú del restaurante.
- **Por pagar**: vista de mesas y reservas pendientes de cobro.
- **Configuración de mesas** *(solo administradores)*: organizar el layout del salón, generar códigos QR por mesa e imprimir/exportar PDF.
- **Tiempo real** con SignalR para actualizaciones de sesiones de mesa (carrito, participantes, confirmaciones).
- **Internacionalización** en español e inglés.
- **Temas personalizables** por restaurante (colores, nombre, tipografía).

## Plataformas soportadas

| Plataforma | Soporte |
|------------|---------|
| Android    | ✅      |
| iOS        | ✅      |
| Web        | ✅      |
| Windows    | ✅      |

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.12.1`
- Dart `^3.12.1`
- Backend de la plataforma de restaurantes en ejecución (API REST + hub SignalR)
- Credenciales de Google Sign-In configuradas para Android/iOS/Web según la plataforma de destino

## Configuración

### 1. Dependencias

```bash
flutter pub get
```

### 2. Conexión con el backend

Edita `assets/cfg/appsettings.json` con la URL de tu API y el ID del restaurante:

```json
{
  "apiBaseUrl": "https://tu-api.ejemplo.com",
  "restaurantId": "uuid-del-restaurante"
}
```

### 3. Tema del restaurante

Ajusta la apariencia en `assets/cfg/theme_config.json`:

```json
{
  "restaurantName": "El Comelón",
  "primaryColor": "#FF5722",
  "secondaryColor": "#FFC107",
  "backgroundColor": "#F5F5F5",
  "surfaceColor": "#FFFFFF",
  "textOnPrimary": "#FFFFFF",
  "textOnBackground": "#212121"
}
```

También existen temas de ejemplo en `assets/cfg/` (`piztheme.json`, `corraltheme.json`, etc.).

### 4. Google Sign-In

Configura el proyecto de Google Cloud y los archivos nativos correspondientes:

- **Android**: SHA-1 en Firebase/Google Cloud + `google-services.json` si aplica.
- **iOS**: `GoogleService-Info.plist` y URL schemes en `Info.plist`.
- **Web**: Client ID en la configuración de `google_sign_in`.

## Ejecución

```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en un dispositivo concreto
flutter run -d <device_id>

# Ejemplos
flutter run -d chrome
flutter run -d windows
```

## Estructura del proyecto

```
lib/
├── core/           # Configuración, red (Dio), utilidades
├── domain/         # Modelos, contratos de repositorios, excepciones
├── infrastructure/ # Implementaciones de repositorios y servicios
└── presentation/   # BLoCs/Cubits, pantallas, widgets y shell principal
```

Patrón de estado: **flutter_bloc**. Comunicación HTTP con **Dio** y eventos en tiempo real con **signalr_netcore**.

## Flujo de la aplicación

```
Login (Google) → Selección de sucursal → Shell principal
                                              ├── Reservas activas
                                              ├── Mesas (admin)
                                              └── Por pagar
```

Desde el menú lateral también se puede acceder a **Pedido manual**.

## Roles

| Rol        | Permisos principales                                      |
|------------|-----------------------------------------------------------|
| Mesero     | Reservas, pedidos manuales, marcar listo para pagar     |
| Admin      | Todo lo anterior + configuración de layout y QR de mesas  |

## Scripts útiles

```bash
# Análisis estático
flutter analyze

# Tests
flutter test

# Generar iconos de la app
dart run flutter_launcher_icons
```

## Dependencias principales

| Paquete                    | Uso                              |
|----------------------------|----------------------------------|
| `flutter_bloc`             | Gestión de estado                |
| `dio`                      | Cliente HTTP                     |
| `google_sign_in`           | Autenticación Google             |
| `signalr_netcore`          | WebSockets / tiempo real         |
| `flutter_map` + `geolocator` | Mapas y geolocalización        |
| `pdf` + `printing`         | Generación e impresión de QR     |
| `google_fonts`             | Tipografía                       |

## Notas de desarrollo

- En modo **debug/profile**, el inicio de sesión puede desactivarse temporalmente mediante `AuthConfig` (en **release** siempre es obligatorio).
- La app acepta certificados autofirmados en desarrollo (`MyHttpOverrides` en `main.dart`); no usar esa configuración en producción.
- Las cadenas de texto están en `assets/i18n/es.json` y `assets/i18n/en.json`.

## Licencia

Proyecto privado — no publicado en pub.dev (`publish_to: 'none'`).
