# Configuración de Fuentes del Proyecto

Para mantener la consistencia visual, se han definido las siguientes familias de fuentes:

- **TitleFont** (`titles_font.otf`): Usada para títulos y encabezados. (Estilo: Bold por defecto).
- **BodyFont** (`body_font.ttf`): Usada para textos informativos, descripciones y contenido general. (Estilo: Bold por defecto).
- **ButtonFont** (`button_font.ttf`): Usada exclusivamente para el texto dentro de los botones interactivos.

## Uso en Código (Flutter)

```dart
// Títulos
Text("EJEMPLO", style: TextStyle(fontFamily: 'TitleFont'))

// Cuerpo
Text("Ejemplo de cuerpo", style: TextStyle(fontFamily: 'BodyFont'))

// Botones
Text("BOTÓN", style: TextStyle(fontFamily: 'ButtonFont'))
```
