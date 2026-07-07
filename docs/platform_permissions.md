# Permisos y configuración de plataforma de LINERB

## Alcance

LINERB V1 utiliza estas capacidades nativas:

- Cámara: captura hasta dos fotografías por hallazgo mediante `image_picker`.
- Ubicación: obtiene una posición puntual de alta precisión mediante `geolocator`.
- Red: descarga los catálogos de troncales y ramales por HTTPS.
- Archivos: lee fotografías temporales creadas por `image_picker` para incorporarlas al PDF.

El flujo actual no selecciona imágenes desde la galería, no graba video o audio, no obtiene ubicación en segundo plano y no guarda archivos en almacenamiento público.

## Android

Archivo principal: `android/app/src/main/AndroidManifest.xml`.

| Declaración | Uso en LINERB | Estado |
|---|---|---|
| `android.permission.INTERNET` | Descarga `troncales.json` y `ramales.json` desde Firebase Hosting. | Declarado en el manifiesto principal para debug, profile y release. |
| `android.permission.ACCESS_FINE_LOCATION` | Obtiene coordenadas con alta precisión para un hallazgo. | Declarado; `geolocator` solicita autorización en ejecución. |
| `android.permission.ACCESS_COARSE_LOCATION` | Permite al sistema ofrecer ubicación aproximada cuando el usuario no concede precisión. | Declarado; Android decide el nivel autorizado. |
| `android.permission.CAMERA` | Captura fotografías de hallazgos. | Declarado; `image_picker_android` gestiona la solicitud en ejecución cuando detecta el permiso en el manifiesto. |

### Permisos Android no añadidos

- `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` y `MANAGE_EXTERNAL_STORAGE`: no son necesarios. `image_picker` usa almacenamiento con alcance y entrega archivos en la caché de la aplicación.
- `READ_MEDIA_IMAGES`: no es necesario para el flujo actual de cámara. El selector moderno de fotos tampoco requiere acceso amplio a la biblioteca.
- `ACCESS_BACKGROUND_LOCATION`: LINERB sólo obtiene una posición mientras la pantalla está activa.
- `FOREGROUND_SERVICE_LOCATION`: LINERB no ejecuta un servicio de seguimiento de ubicación.

Los manifiestos `android/app/src/debug/AndroidManifest.xml` y `android/app/src/profile/AndroidManifest.xml` conservan su configuración de desarrollo. El permiso de red también está en el manifiesto principal para que no desaparezca del build release.

## iOS

Archivo: `ios/Runner/Info.plist`.

| Clave | Uso en LINERB |
|---|---|
| `NSCameraUsageDescription` | Explica al usuario por qué se abre la cámara para documentar hallazgos. |
| `NSPhotoLibraryUsageDescription` | Declaración requerida por la configuración de `image_picker` y preparada para selección de imágenes. El flujo V1 todavía no abre la fototeca. |
| `NSLocationWhenInUseUsageDescription` | Explica la obtención de coordenadas mientras LINERB está abierta. |

### Configuración iOS no añadida

- `NSMicrophoneUsageDescription`: no se graba video ni audio.
- `NSPhotoLibraryAddUsageDescription`: LINERB no guarda imágenes en la fototeca.
- `NSLocationAlwaysAndWhenInUseUsageDescription` y `UIBackgroundModes/location`: no existe seguimiento en segundo plano.
- Excepciones de App Transport Security: los catálogos se consultan por HTTPS.

iOS administra el espacio privado de la aplicación, por lo que no existe un permiso genérico de almacenamiento equivalente al de versiones antiguas de Android.

## macOS

Archivos:

- `macos/Runner/Info.plist`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

Configuración incorporada:

| Clave o entitlement | Uso |
|---|---|
| `NSLocationUsageDescription` | Describe el uso de ubicación en macOS. |
| `com.apple.security.personal-information.location` | Autoriza ubicación dentro del sandbox en debug/profile y release. |
| `com.apple.security.network.client` | Autoriza conexiones salientes HTTPS para descargar catálogos. |

`ImageSource.camera` no está soportado por defecto en las implementaciones de escritorio de `image_picker`; requiere un `cameraDelegate`. No se añadieron permisos de cámara o selección de archivos en macOS porque hacerlo no habilitaría el flujo actual y ampliaría permisos sin uso efectivo. Resolver esa limitación requiere una decisión de plataforma y queda fuera de este bloque de Fase 1.

## Windows, Linux y Web

- Windows y Linux no requieren manifiestos equivalentes para las capacidades usadas, pero `ImageSource.camera` tampoco funciona sin un delegado de cámara de escritorio.
- En web, ubicación y acceso a cámara dependen de permisos del navegador y de un origen seguro. La compilación web actual tiene otras limitaciones de compatibilidad, como el uso directo de `dart:io`, que no forman parte de este cambio.

## Pruebas manuales recomendadas

### Android release

1. Instalar un build release limpio.
2. Verificar que el catálogo remoto carga con conectividad.
3. Rechazar y luego conceder ubicación; confirmar que ambos estados se manejan sin cierre inesperado.
4. Abrir cámara, rechazar y luego conceder permiso; confirmar la captura.
5. Verificar que no se solicita acceso amplio al almacenamiento.

### iOS

1. Instalar la aplicación limpia en un dispositivo físico.
2. Confirmar que cámara y ubicación muestran las descripciones configuradas.
3. Probar denegación y concesión desde Ajustes.
4. Confirmar que no se solicita micrófono ni ubicación permanente.
