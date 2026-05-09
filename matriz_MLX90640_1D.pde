import processing.serial.*;

Serial puerto;

// =======================
// DATOS SENSOR REAL
// =======================
float[] matriz = new float[32 * 24];

float tempObjeto = 0;
float tempAmbiente = 25;
float zActual = 0;
int anguloServo = 0;

float mlxMin = 0;
float mlxMax = 0;
float mlxMedia = 0;

int cols = 32;
int rows = 24;
int escala = 14;

// =======================
// ESCALA SENSOR REAL
// =======================
boolean modoAutoescala = true;

float tMinFijo = 20;
float tMaxFijo = 300;

float frameMin = 20;
float frameMax = 300;

// =======================
// HOTSPOT
// =======================
int hotX = 0;
int hotY = 0;
float hotTemp = 0;

// =======================
// SIMULACION 1D GUIADA POR SENSOR
// =======================
int N = 80;
float[] T = new float[N];
float[] Tnext = new float[N];

float T_amb = 25;

// r controla cuánto se propaga el calor entre nodos.
// Debe ser <= 0.5 para que el esquema explícito sea estable.
float r = 0.18;

// Pérdida simple hacia el ambiente.
// Representa de forma simplificada la convección natural.
float perdidaAmbiente = 0.002;

// Escala visual de la simulación
float simMin = 20;
float simMax = 80;

// =======================
// CSV
// =======================
PrintWriter csv;
int CSV_INTERVAL_MS = 500;
int lastCsvSave = 0;

// =======================
// LAYOUT
// =======================
int matrizX = 0;
int matrizY = 0;
int matrizW = cols * escala;
int matrizH = rows * escala;

int barraRealX = matrizW + 20;
int barraRealY = 30;
int barraRealW = 28;
int barraRealH = matrizH - 60;

int simX = 570;
int simY = 90;
int simW = 440;
int simH = 90;

int panelY = 430;

void setup() {
  size(1080, 650);
  printArray(Serial.list());

  puerto = new Serial(this, Serial.list()[0], 115200);
  puerto.bufferUntil('\n');

  textSize(15);
  smooth();

  for (int i = 0; i < N; i++) {
    T[i] = T_amb;
    Tnext[i] = T_amb;
  }

  csv = createWriter("datos_termicos_simulacion.csv");
  csv.println("tiempo_ms,temp_objeto_mlx90614,temp_ambiente_mlx90614,mlx90640_min,mlx90640_max,mlx90640_media,hotspot_temp,hotspot_x,hotspot_y,z_actual,angulo_servo,tipo_simulacion,temp_sim_inicio,temp_sim_medio,temp_sim_fin,sim_min,sim_max");
  csv.flush();
}

void draw() {
  background(0);

  actualizarSimulacionGuiadaPorSensor();
  calcularRangoVisual();
  calcularEscalaSimulacion();

  dibujarMatrizReal();
  dibujarHotspot();
  dibujarBarraVerticalReal();

  dibujarSimulacionCable();
  dibujarPanelTexto();

  if (millis() - lastCsvSave >= CSV_INTERVAL_MS) {
    lastCsvSave = millis();
    guardarCSV();
  }
}

// =======================
// SERIAL
// =======================
void serialEvent(Serial p) {
  String linea = p.readStringUntil('\n');
  if (linea == null) return;

  linea = trim(linea);
  if (linea.length() == 0) return;

  String[] partes = split(linea, ',');
  if (partes.length == 0) return;

  if (partes[0].equals("FRAME")) {
    if (partes.length == 1 + 32 * 24) {
      for (int i = 0; i < 32 * 24; i++) {
        matriz[i] = float(partes[i + 1]);
      }
    }
  } 
  else if (partes[0].equals("TEMP")) {
    if (partes.length >= 3) {
      tempObjeto = float(partes[1]);
      tempAmbiente = float(partes[2]);
      T_amb = tempAmbiente;
    }
  } 
  else if (partes[0].equals("SERVO")) {
    if (partes.length >= 3) {
      zActual = float(partes[1]);
      anguloServo = int(float(partes[2]));
    }
  } 
  else if (partes[0].equals("STATS")) {
    if (partes.length >= 4) {
      mlxMin = float(partes[1]);
      mlxMax = float(partes[2]);
      mlxMedia = float(partes[3]);
    }
  } 
  else {
    println(linea);
  }
}

// =======================
// SIMULACION 1D REALISTA
// =======================
void actualizarSimulacionGuiadaPorSensor() {
  // La fuente térmica del extremo izquierdo es la temperatura real máxima
  // detectada por el MLX90640.
  float fuente = mlxMax;

  // Si todavía no hay dato válido, usamos ambiente.
  if (fuente <= 0) {
    fuente = T_amb;
  }

  // Extremo izquierdo: temperatura medida por el sensor.
  T[0] = fuente;

  // Extremo derecho: ambiente.
  T[N - 1] = T_amb;

  // Modelo ligero de conducción 1D + pérdida simple al ambiente.
  for (int i = 1; i < N - 1; i++) {
    float conduccion = r * (T[i + 1] - 2 * T[i] + T[i - 1]);
    float perdida = perdidaAmbiente * (T[i] - T_amb);

    Tnext[i] = T[i] + conduccion - perdida;
  }

  Tnext[0] = fuente;
  Tnext[N - 1] = T_amb;

  for (int i = 0; i < N; i++) {
    T[i] = Tnext[i];
  }
}

void calcularEscalaSimulacion() {
  float minV = T[0];
  float maxV = T[0];

  for (int i = 1; i < N; i++) {
    if (T[i] < minV) minV = T[i];
    if (T[i] > maxV) maxV = T[i];
  }

  if (maxV - minV < 5) {
    maxV = minV + 5;
  }

  simMin = lerp(simMin, minV, 0.15);
  simMax = lerp(simMax, maxV, 0.15);
}

// =======================
// MATRIZ REAL
// =======================
void calcularRangoVisual() {
  float minV = matriz[0];
  float maxV = matriz[0];
  int maxIndex = 0;

  for (int i = 1; i < matriz.length; i++) {
    if (matriz[i] < minV) minV = matriz[i];

    if (matriz[i] > maxV) {
      maxV = matriz[i];
      maxIndex = i;
    }
  }

  hotTemp = maxV;
  hotX = maxIndex % cols;
  hotY = maxIndex / cols;

  if (!modoAutoescala) {
    frameMin = tMinFijo;
    frameMax = tMaxFijo;
  } else {
    if (maxV - minV < 5.0) maxV = minV + 5.0;
    frameMin = lerp(frameMin, minV, 0.15);
    frameMax = lerp(frameMax, maxV, 0.15);
  }
}

void dibujarMatrizReal() {
  noStroke();

  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      int i = y * cols + x;
      fill(colorTermico(matriz[i], frameMin, frameMax));
      rect(matrizX + x * escala, matrizY + y * escala, escala, escala);
    }
  }

  fill(255);
  text("Lectura real MLX90640", matrizX + 12, matrizY + matrizH + 25);
}

void dibujarHotspot() {
  int px = matrizX + hotX * escala + escala / 2;
  int py = matrizY + hotY * escala + escala / 2;

  noFill();
  stroke(255, 255, 255);
  strokeWeight(2);
  ellipse(px, py, escala + 4, escala + 4);

  stroke(255, 0, 0);
  strokeWeight(2);
  line(px - 7, py, px + 7, py);
  line(px, py - 7, px, py + 7);

  noStroke();
}

void dibujarBarraVerticalReal() {
  for (int i = 0; i < barraRealH; i++) {
    float n = map(i, barraRealH, 0, 0, 1);
    float tempBarra = map(n, 0, 1, frameMin, frameMax);
    stroke(colorTermico(tempBarra, frameMin, frameMax));
    line(barraRealX, barraRealY + i, barraRealX + barraRealW, barraRealY + i);
  }

  noStroke();
  fill(255);
  textAlign(LEFT);
  text(nf(frameMax, 0, 1) + " C", barraRealX + 38, barraRealY + 12);
  text(nf(frameMin, 0, 1) + " C", barraRealX + 38, barraRealY + barraRealH);
}

// =======================
// SIMULACION VISUAL
// =======================
void dibujarSimulacionCable() {
  fill(255);
  textAlign(LEFT);
  text("Simulación 1D del cable", simX, simY - 45);
  text("Extremo guiado por MLX90640 Max", simX, simY - 8);
  textAlign(RIGHT);
  text("Ambiente", simX + simW, simY - 8);
  textAlign(LEFT);

  noStroke();

  float cellW = simW / float(N);

  for (int i = 0; i < N; i++) {
    fill(colorTermico(T[i], simMin, simMax));
    rect(simX + i * cellW, simY, cellW + 1, simH);
  }

  stroke(255);
  noFill();
  rect(simX, simY, simW, simH);

  noStroke();
  fill(255);
  text("Simulación guiada por lectura real", simX, simY + simH + 35);
  text("Fuente = MLX90640 Max: " + nf(mlxMax, 0, 2) + " C", simX, simY + simH + 58);

  dibujarBarraHorizontal(simX, simY + simH + 80, simW, 16, simMin, simMax);
}

// =======================
// PANEL
// =======================
void dibujarPanelTexto() {
  noStroke();
  fill(0);
  rect(0, panelY, width, height - panelY);

  int col1 = 20;
  int col2 = 390;
  int col3 = 720;
  int y0 = panelY + 35;
  int dy = 26;

  fill(255, 0, 0);
  text("Hotspot MLX90640: " + nf(hotTemp, 0, 2) + " C", col1, y0);
  text("Hotspot X: " + hotX + "  Y: " + hotY, col1, y0 + dy);

  fill(255);
  text("MLX90640 Min: " + nf(mlxMin, 0, 2) + " C", col1, y0 + 2 * dy);
  text("MLX90640 Max: " + nf(mlxMax, 0, 2) + " C", col1, y0 + 3 * dy);
  text("MLX90640 Media: " + nf(mlxMedia, 0, 2) + " C", col1, y0 + 4 * dy);

  fill(colorSegunTemperatura(tempObjeto));
  text("MLX90614 Objeto: " + nf(tempObjeto, 0, 2) + " C", col2, y0);

  fill(255);
  text("MLX90614 Ambiente: " + nf(tempAmbiente, 0, 2) + " C", col2, y0 + dy);
  text("Z actual: " + nf(zActual, 0, 2), col2, y0 + 3 * dy);
  text("Ángulo servo: " + anguloServo, col2, y0 + 4 * dy);

  fill(180);
  text("Escala sensor: " + (modoAutoescala ? "AUTO" : "FIJO"), col3, y0);
  text("Simulación: guiada por sensor", col3, y0 + dy);

  fill(255);
  text("Sensor min: " + nf(frameMin, 0, 1) + " C", col3, y0 + 3 * dy);
  text("Sensor max: " + nf(frameMax, 0, 1) + " C", col3, y0 + 4 * dy);
  text("Sim min: " + nf(simMin, 0, 1) + " C", col3, y0 + 5 * dy);
  text("Sim max: " + nf(simMax, 0, 1) + " C", col3, y0 + 6 * dy);

  fill(200);
  text("Teclas: A AUTO/FIJO | R reinicia simulación | C captura", col1, height - 20);
}

// =======================
// CSV
// =======================
void guardarCSV() {
  String tipoSimulacion = "guiada_por_sensor";

  float tempInicio = T[0];
  float tempMedio = T[N / 2];
  float tempFin = T[N - 1];

  csv.print(millis());
  csv.print(",");
  csv.print(tempObjeto);
  csv.print(",");
  csv.print(tempAmbiente);
  csv.print(",");
  csv.print(mlxMin);
  csv.print(",");
  csv.print(mlxMax);
  csv.print(",");
  csv.print(mlxMedia);
  csv.print(",");
  csv.print(hotTemp);
  csv.print(",");
  csv.print(hotX);
  csv.print(",");
  csv.print(hotY);
  csv.print(",");
  csv.print(zActual);
  csv.print(",");
  csv.print(anguloServo);
  csv.print(",");
  csv.print(tipoSimulacion);
  csv.print(",");
  csv.print(tempInicio);
  csv.print(",");
  csv.print(tempMedio);
  csv.print(",");
  csv.print(tempFin);
  csv.print(",");
  csv.print(simMin);
  csv.print(",");
  csv.println(simMax);

  csv.flush();
}

// =======================
// COLORES Y BARRAS
// =======================
color colorTermico(float valor, float minV, float maxV) {
  float n = map(valor, minV, maxV, 0, 1);
  n = constrain(n, 0, 1);

  if (n < 0.20) {
    return lerpColor(color(0, 0, 80), color(0, 0, 255), n / 0.20);
  } else if (n < 0.40) {
    return lerpColor(color(0, 0, 255), color(128, 0, 255), (n - 0.20) / 0.20);
  } else if (n < 0.60) {
    return lerpColor(color(128, 0, 255), color(255, 0, 255), (n - 0.40) / 0.20);
  } else if (n < 0.80) {
    return lerpColor(color(255, 0, 255), color(255, 165, 0), (n - 0.60) / 0.20);
  } else {
    return lerpColor(color(255, 165, 0), color(255, 0, 0), (n - 0.80) / 0.20);
  }
}

color colorSegunTemperatura(float t) {
  if (t < 80) return color(255);
  if (t < 150) return color(255, 200, 0);
  return color(255, 0, 0);
}

void dibujarBarraHorizontal(int x, int y, int w, int h, float minT, float maxT) {
  for (int i = 0; i < w; i++) {
    float n = map(i, 0, w, 0, 1);
    float temp = map(n, 0, 1, minT, maxT);
    stroke(colorTermico(temp, minT, maxT));
    line(x + i, y, x + i, y + h);
  }

  noStroke();
  fill(255);
  textAlign(LEFT);
  text(nf(minT, 0, 1) + " C", x, y + h + 20);
  textAlign(RIGHT);
  text(nf(maxT, 0, 1) + " C", x + w, y + h + 20);
  textAlign(LEFT);
}

// =======================
// TECLAS
// =======================
void keyPressed() {
  if (key == 'a' || key == 'A') {
    modoAutoescala = !modoAutoescala;
  }

  if (key == 'r' || key == 'R') {
    for (int i = 0; i < N; i++) {
      T[i] = T_amb;
      Tnext[i] = T_amb;
    }
  }

  if (key == 'c' || key == 'C') {
    saveFrame("captura_termica_####.png");
  }
}

void exit() {
  csv.flush();
  csv.close();
  super.exit();
}
