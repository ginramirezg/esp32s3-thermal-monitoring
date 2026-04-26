#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <ESP32Servo.h>
#include <Adafruit_MLX90640.h>
#include <Adafruit_MLX90614.h>

// =========================
// PINES
// =========================
#define I2C_SDA   17
#define I2C_SCL   18

#define SD_SCK    12
#define SD_MISO   13
#define SD_MOSI   11
#define SD_CS     10

#define SERVO_PIN 8

Adafruit_MLX90640 mlx90640;
Adafruit_MLX90614 mlx90614 = Adafruit_MLX90614();

Servo miServo;
File gcodeFile;

float frame[32 * 24];

// =========================
// TIEMPOS DE LECTURA
// =========================
// esto es cada cuanto leo el MLX90640 (la matriz)
// si lo bajo va más rápido pero puede petar más fácil
const unsigned long MLX90640_INTERVAL_MS = 1000;
unsigned long lastMLX90640Read = 0;

// esto es para el MLX90614 (temperatura puntual)
// puedo bajarlo si quiero más refresco
const unsigned long MLX90614_INTERVAL_MS = 1000;
unsigned long lastMLX90614Read = 0;

// =========================
// ARCHIVO GCODE
// =========================
const char* GCODE_FILE = "/CE3E3V2_PruebaGina.gcode";

// =========================
// AJUSTE MOVIMIENTO SERVO
// =========================

// ESTO ES CLAVE
// aquí estoy diciendo qué rango de Z del gcode uso
// ahora mismo:
// Z = 0   -> mínimo del servo
// Z = 100 -> máximo del servo
//
// si veo que el servo se mueve muy poco:
//   BAJO el Z_MAX (por ejemplo a 20 o 10)
//
// si veo que se mueve demasiado brusco:
//   SUBO el Z_MAX
const float Z_MIN = 0.0;
const float Z_MAX = 100.0;

// esto es el recorrido real del servo
//
// si quiero que el servo se mueva más físicamente:
//   aumento el rango (ej: 0 a 180)
//
// si quiero limitarlo:
//   reduzco estos valores
//
// ojo porque si lo llevo al límite puede forzar el servo
const int SERVO_MIN_ANGLE = 10;
const int SERVO_MAX_ANGLE = 170;

// esto es cada cuanto leo una línea del gcode
//
// si el servo va muy rápido:
//   subo este valor (ej: 500)
//
// si quiero que responda más rápido:
//   lo bajo
const unsigned long GCODE_INTERVAL_MS = 200;
unsigned long lastGcodeStep = 0;

float lastZ = -9999.0;
bool gcodeFinished = false;
bool sdOK = false;

// esto es para evitar el tirón al arrancar
// el servo no se mueve hasta que llega el primer Z real
bool servoInicializado = false;

void setup() {
  Serial.begin(115200);
  delay(1500);

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(50000);
  Wire.setTimeOut(100);
  delay(500);

  if (!mlx90640.begin(0x33, &Wire)) {
    Serial.println("ERROR,MLX90640");
    while (1) delay(1000);
  }

  mlx90640.setMode(MLX90640_INTERLEAVED);
  mlx90640.setResolution(MLX90640_ADC_16BIT);
  mlx90640.setRefreshRate(MLX90640_1_HZ);

  if (!mlx90614.begin()) {
    Serial.println("ERROR,MLX90614");
    while (1) delay(1000);
  }

  // no pongo write(90) para que no pegue el tirón al arrancar
  miServo.setPeriodHertz(50);
  miServo.attach(SERVO_PIN, 500, 2400);
  delay(500);

  iniciarSDyGcode();

  Serial.println("READY");
}

void loop() {
  unsigned long now = millis();

  if (now - lastMLX90614Read >= MLX90614_INTERVAL_MS) {
    lastMLX90614Read = now;
    leerMLX90614();
  }

  if (now - lastMLX90640Read >= MLX90640_INTERVAL_MS) {
    lastMLX90640Read = now;
    leerMLX90640();
  }

  if (sdOK && !gcodeFinished && now - lastGcodeStep >= GCODE_INTERVAL_MS) {
    lastGcodeStep = now;
    procesarSiguienteLineaGcode();
  }
}

void iniciarSDyGcode() {
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);

  if (!SD.begin(SD_CS, SPI, 1000000)) {
    Serial.println("ERROR,SD");
    sdOK = false;
    return;
  }

  if (!SD.exists(GCODE_FILE)) {
    Serial.println("ERROR,GCODE_NOT_FOUND");
    sdOK = false;
    return;
  }

  gcodeFile = SD.open(GCODE_FILE, FILE_READ);
  if (!gcodeFile) {
    Serial.println("ERROR,GCODE_OPEN");
    sdOK = false;
    return;
  }

  sdOK = true;
}

void leerMLX90614() {
  float tempObjeto = mlx90614.readObjectTempC();
  float tempAmbiente = mlx90614.readAmbientTempC();

  Serial.print("TEMP,");
  Serial.print(tempObjeto, 2);
  Serial.print(",");
  Serial.println(tempAmbiente, 2);
}

void leerMLX90640() {
  int status = mlx90640.getFrame(frame);

  if (status != 0) {
    Serial.print("ERROR_FRAME,");
    Serial.println(status);
    return;
  }

  float minTemp = frame[0];
  float maxTemp = frame[0];
  float suma = 0;

  for (int i = 0; i < 32 * 24; i++) {
    float t = frame[i];

    if (t < minTemp) minTemp = t;
    if (t > maxTemp) maxTemp = t;

    suma += t;
  }

  float media = suma / (32 * 24);

  Serial.print("STATS,");
  Serial.print(minTemp, 2);
  Serial.print(",");
  Serial.print(maxTemp, 2);
  Serial.print(",");
  Serial.println(media, 2);

  Serial.print("FRAME");
  for (int i = 0; i < 32 * 24; i++) {
    Serial.print(",");
    Serial.print(frame[i], 1);
  }
  Serial.println();
}

void procesarSiguienteLineaGcode() {
  if (!gcodeFile || !gcodeFile.available()) {
    gcodeFinished = true;
    if (gcodeFile) gcodeFile.close();
    Serial.println("FIN_GCODE");
    return;
  }

  while (gcodeFile.available()) {
    String linea = gcodeFile.readStringUntil('\n');
    linea.trim();

    if (linea.length() == 0) continue;
    if (linea.startsWith(";")) continue;

    if (linea.startsWith("G0") || linea.startsWith("G1")) {
      if (contieneEje(linea, 'Z')) {
        float z = extraerValorEje(linea, 'Z');

        if (abs(z - lastZ) > 0.001) {
          int angulo = mapFloatToServo(z, Z_MIN, Z_MAX, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
          angulo = constrain(angulo, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);

          if (!servoInicializado) {
            miServo.write(angulo);
            servoInicializado = true;
            Serial.println("SERVO_INIT");
          } else {
            miServo.write(angulo);
          }

          lastZ = z;

          Serial.print("SERVO,");
          Serial.print(z, 3);
          Serial.print(",");
          Serial.println(angulo);
        }
        return;
      }
    }
  }

  gcodeFinished = true;
  if (gcodeFile) gcodeFile.close();
  Serial.println("FIN_GCODE");
}

bool contieneEje(const String& linea, char eje) {
  return linea.indexOf(eje) != -1;
}

float extraerValorEje(const String& linea, char eje) {
  int pos = linea.indexOf(eje);
  if (pos == -1) return 0.0;

  int start = pos + 1;
  int end = start;

  while (end < linea.length()) {
    char c = linea[end];
    if ((c >= '0' && c <= '9') || c == '.' || c == '-') {
      end++;
    } else {
      break;
    }
  }

  String numero = linea.substring(start, end);
  return numero.toFloat();
}

int mapFloatToServo(float x, float in_min, float in_max, int out_min, int out_max) {
  if (in_max == in_min) return out_min;
  float resultado = (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
  return (int)resultado;
}