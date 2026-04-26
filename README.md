# esp32s3-thermal-monitoring
Diseño de un sistema empotrado de monitorización de temperatura para impresión 3D


# Sistema empotrado de monitorización térmica con ESP32-S3

Este proyecto forma parte de un Trabajo de Fin de Grado orientado al diseño de un sistema empotrado para la monitorización de temperatura en procesos de impresión 3D. El prototipo utiliza una placa **ESP32-S3** junto con sensores infrarrojos para capturar datos térmicos, visualizarlos en tiempo real y almacenarlos en formato CSV para su posterior análisis.

El sistema se ha probado inicialmente en un entorno de impresión FFF con una impresora **Ender/Creality**, y también mediante una prueba complementaria con **placas metálicas calentadas aproximadamente hasta 130 °C y apiladas entre sí**, con el objetivo de ampliar el rango térmico registrado.

---

## Objetivo del proyecto

El objetivo principal del proyecto es desarrollar un sistema capaz de:

- Capturar datos térmicos mediante sensores infrarrojos.
- Visualizar una matriz térmica en tiempo real.
- Registrar las lecturas en un archivo CSV.
- Leer archivos `.gcode` desde una tarjeta microSD.
- Mover un servo en función de valores extraídos del eje Z del G-code.
- Generar datos estructurados que puedan utilizarse en fases posteriores para análisis o modelos de inteligencia artificial.

---

## Componentes utilizados

### Hardware

- ESP32-S3
- Sensor térmico MLX90640
- Sensor infrarrojo puntual MLX90614
- Módulo lector microSD
- Tarjeta microSD
- Servo SG90 / MG996R
- Protoboard
- Cables Dupont
- Condensador de 220 µF
- Fuente de alimentación externa para el servo
- Impresora 3D Ender/Creality
- Placas metálicas para pruebas térmicas

### Software

- Arduino IDE
- Processing
- Librerías de Arduino:
  - `Wire`
  - `SPI`
  - `SD`
  - `ESP32Servo`
  - `Adafruit_MLX90640`
  - `Adafruit_MLX90614`

---

## Estructura del proyecto

```text
ESP32S3-monitorizacion-termica/
│
├── completo.ino
├── matriz_MLX90640.pde
├── datos_termicos_2026-04-22_19-35-00.csv
├── datos_termicos_2026-04-22_19-35-00_modificado_placas_metal.csv
├── README.md
│
├── docs/
│   └── memoria_TFG.docx
│
├── gcode/
│   └── CE3E3V2_PruebaGina.gcode
│
└── imagenes/
    ├── montaje_esp32s3.jpg
    ├── visualizacion_processing.jpg
    └── prueba_placas_metalicas.jpg
````

---

## Funcionamiento general

El funcionamiento del sistema se divide en varias partes:

1. La ESP32-S3 inicializa los sensores MLX90640 y MLX90614.
2. El MLX90640 captura una matriz térmica de 32 x 24 píxeles.
3. El MLX90614 obtiene una temperatura puntual del objeto y del ambiente.
4. La ESP32-S3 calcula valores como temperatura mínima, máxima, media y punto más caliente.
5. Los datos se envían por puerto serie a Processing.
6. Processing representa la matriz térmica en forma de mapa de calor.
7. Los datos se guardan en un archivo CSV.
8. La ESP32-S3 puede leer un archivo `.gcode` desde microSD.
9. A partir del valor del eje Z del G-code, se mueve un servo como prueba de actuación física.

---

## Conexiones utilizadas

| Componente   | Pin ESP32-S3 |
| ------------ | ------------ |
| MLX90640 SDA | GPIO 17      |
| MLX90640 SCL | GPIO 18      |
| MLX90614 SDA | GPIO 17      |
| MLX90614 SCL | GPIO 18      |
| microSD SCK  | GPIO 12      |
| microSD MISO | GPIO 13      |
| microSD MOSI | GPIO 11      |
| microSD CS   | GPIO 10      |
| Servo        | GPIO 8       |

La alimentación de los sensores se realizó a 3.3 V. Para el servo se recomienda utilizar una fuente externa de 5 V, ya que alimentarlo directamente desde la ESP32-S3 puede provocar inestabilidad o reinicios.

---

## Instalación del entorno Arduino

### 1. Instalar Arduino IDE

Se debe descargar e instalar Arduino IDE desde la página oficial:

```text
https://www.arduino.cc/en/software
```

### 2. Añadir soporte para ESP32

En Arduino IDE, abrir:

```text
Archivo > Preferencias
```

En el campo de URLs adicionales del gestor de tarjetas, añadir:

```text
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```

Después ir a:

```text
Herramientas > Placa > Gestor de tarjetas
```

Buscar:

```text
esp32
```

Instalar el paquete de **Espressif Systems**.

### 3. Seleccionar la placa

En Arduino IDE seleccionar una placa compatible con la ESP32-S3, por ejemplo:

```text
ESP32S3 Dev Module
```

---

## Librerías necesarias

Desde el gestor de librerías de Arduino IDE se deben instalar:

```text
Adafruit MLX90640
Adafruit MLX90614
ESP32Servo
```

También se utilizan librerías incluidas por defecto:

```cpp
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
```

---

## Carga del firmware en la ESP32-S3

Abrir el archivo:

```text
completo.ino
```

Seleccionar el puerto correspondiente a la ESP32-S3, por ejemplo:

```text
COM6
```

Compilar y cargar el programa desde Arduino IDE.

---

## Configuración del archivo G-code

El sistema está preparado para leer un archivo `.gcode` desde la tarjeta microSD.

En el código se utiliza el siguiente nombre de archivo:

```cpp
const char* GCODE_FILE = "/CE3E3V2_PruebaGina.gcode";
```

Por tanto, la tarjeta microSD debe contener un archivo con ese nombre en la raíz:

```text
/CE3E3V2_PruebaGina.gcode
```

El programa interpreta comandos `G0` y `G1`, extrayendo principalmente el valor del eje `Z`.

Ejemplo de línea G-code:

```gcode
G1 X50 Y50 Z0.28 F1500
```

A partir del valor de `Z`, el sistema calcula un ángulo para mover el servo.

---

## Visualización en Processing

Para visualizar la matriz térmica se utiliza Processing.

### 1. Instalar Processing

Descargar Processing desde:

```text
https://processing.org/download
```

### 2. Abrir el archivo de visualización

Abrir el archivo:

```text
matriz_MLX90640.pde
```

### 3. Configurar el puerto serie

En el código de Processing debe seleccionarse el puerto donde está conectada la ESP32-S3.

Ejemplo:

```java
puerto = new Serial(this, "COM6", 115200);
```

Si la ESP32-S3 aparece en otro puerto, se debe modificar `"COM6"` por el puerto correspondiente.

### 4. Ejecutar el programa

Al ejecutar Processing, se mostrará una representación visual de la matriz térmica de 32 x 24 píxeles, junto con valores como temperatura mínima, máxima, media y punto más caliente.

---

## Formato del CSV generado

Los datos térmicos se almacenan en un archivo CSV con una estructura similar a la siguiente:

| Campo          | Descripción                                           |
| -------------- | ----------------------------------------------------- |
| `timestamp`    | Instante de captura de la muestra                     |
| `tempObjeto`   | Temperatura puntual del objeto medida por el MLX90614 |
| `tempAmbiente` | Temperatura ambiente medida por el MLX90614           |
| `mlxMin`       | Temperatura mínima de la matriz MLX90640              |
| `mlxMax`       | Temperatura máxima de la matriz MLX90640              |
| `mlxMedia`     | Temperatura media de la matriz MLX90640               |
| `hotX`         | Coordenada X del punto más caliente                   |
| `hotY`         | Coordenada Y del punto más caliente                   |
| `hotTemp`      | Temperatura del punto más caliente                    |
| `zActual`      | Valor del eje Z extraído del G-code                   |
| `anguloServo`  | Ángulo aplicado al servo                              |

---

## Pruebas realizadas

### Prueba con impresora Ender/Creality

Se realizó una prueba inicial con una impresora FFF Ender/Creality. Esta prueba permitió validar que el sistema podía capturar datos térmicos durante un proceso de impresión real, visualizar la matriz térmica en Processing y registrar la información en un archivo CSV.

Durante esta fase se comprobó:

* Lectura correcta del MLX90640.
* Lectura puntual del MLX90614.
* Envío de datos por puerto serie.
* Visualización en Processing.
* Registro de datos en CSV.
* Lectura de G-code desde microSD.
* Movimiento del servo según el valor Z.

### Prueba con placas metálicas calentadas

También se realizó una prueba complementaria con placas metálicas calentadas aproximadamente hasta 130 °C. Las placas se fueron apilando entre sí para observar la respuesta del sistema ante una fuente térmica más intensa.

Esta prueba permitió ampliar el rango térmico del dataset, incorporando valores aproximados entre 60 °C y 130 °C.

Resumen:

| Ensayo                      | Nº de registros | Rango aproximado       |
| --------------------------- | --------------: | ---------------------- |
| Impresión Ender/Creality    |             496 | Temperaturas moderadas |
| Placas metálicas calentadas |             120 | 60 °C - 130 °C         |
| Total                       |             616 | Dataset combinado      |

---

## Resultados obtenidos

Los resultados muestran que el sistema es capaz de capturar, visualizar y registrar información térmica de forma continua. La prueba con la impresora Ender/Creality permitió validar el flujo completo en un entorno FFF, mientras que la prueba con placas metálicas permitió ampliar el rango térmico registrado.

El CSV ampliado contiene un total de 616 registros, combinando los datos originales de impresión con los datos añadidos de la prueba térmica con placas metálicas.

Estos datos pueden servir como base para fases posteriores de análisis, definición de ventanas térmicas o aplicación de técnicas de inteligencia artificial.

---

## Posible adaptación a Meltio

Aunque las pruebas se realizaron en un entorno FFF y con placas metálicas calentadas, el sistema se plantea como una base inicial para una posible adaptación a procesos de fabricación aditiva metálica, como los sistemas Meltio basados en deposición láser-hilo.

Para una futura integración en un entorno Meltio sería necesario realizar modificaciones importantes:

* Proteger los sensores frente a radiación intensa.
* Evitar daños por proyecciones de material o polvo metálico.
* Colocar los sensores a una distancia segura.
* Diseñar una carcasa de protección.
* Utilizar una ventana óptica compatible con infrarrojo.
* Asegurar una fijación estable frente a vibraciones.
* Realizar una calibración específica para materiales metálicos.
* Tener en cuenta la emisividad, los reflejos y la geometría de observación.

Por tanto, el prototipo actual no debe considerarse una solución final directamente aplicable a Meltio, sino una primera versión funcional para validar la adquisición, visualización y registro de datos térmicos.

---

## Limitaciones actuales

El sistema desarrollado presenta algunas limitaciones:

* Las pruebas no se han realizado todavía en un entorno real de fabricación aditiva metálica.
* Las temperaturas alcanzadas en las pruebas son inferiores a las de un proceso Meltio real.
* La medición infrarroja depende de la emisividad del material.
* El MLX90640 tiene una resolución limitada de 32 x 24 píxeles.
* El montaje requiere protección adicional para entornos industriales.
* El modelo de inteligencia artificial queda como trabajo futuro.
* El CSV generado necesita más ensayos para disponer de un dataset más representativo.

---

## Líneas futuras

Como continuación del proyecto, se plantean las siguientes líneas futuras:

* Realizar más pruebas con diferentes materiales y temperaturas.
* Repetir ensayos con distintas distancias entre sensor y pieza.
* Mejorar el sistema de fijación del sensor.
* Diseñar una carcasa protectora para entornos de mayor temperatura.
* Añadir una ventana óptica compatible con infrarrojo.
* Ampliar el dataset con más registros.
* Etiquetar los datos como condiciones normales o anómalas.
* Entrenar modelos de inteligencia artificial para detectar desviaciones térmicas.
* Integrar una lógica de decisión para continuar, detener o ajustar el proceso.
* Probar el sistema en un entorno más cercano a Meltio.

---

## Archivos principales

### `completo.ino`

Firmware principal de la ESP32-S3. Se encarga de:

* Inicializar sensores.
* Leer datos térmicos.
* Leer archivo G-code.
* Controlar el servo.
* Enviar datos por Serial.
* Gestionar microSD.

### `matriz_MLX90640.pde`

Aplicación de Processing para:

* Leer datos desde el puerto serie.
* Dibujar la matriz térmica.
* Mostrar estadísticas.
* Guardar datos en CSV.

### `datos_termicos_2026-04-22_19-35-00.csv`

CSV original generado durante la prueba inicial.

### `datos_termicos_2026-04-22_19-35-00_modificado_placas_metal.csv`

CSV ampliado con la prueba complementaria de placas metálicas calentadas.

---

## Autoría

Proyecto desarrollado por:

```text
Gina Andrea Ramírez Guerrero
Grado en Ingeniería Informática
Trabajo de Fin de Grado
```

---

## Estado del proyecto

El proyecto se encuentra en fase de prototipo funcional. Actualmente permite capturar, visualizar y registrar datos térmicos, así como realizar una prueba de actuación mediante servo a partir de información extraída de un archivo G-code.

La fase de inteligencia artificial queda planteada como continuación del trabajo, una vez ampliado el dataset experimental.

```
```
