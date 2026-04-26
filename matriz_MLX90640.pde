import processing.serial.*;

Serial puerto;
PrintWriter logCSV;

boolean guardarDatos = true;

float[] matriz = new float[32 * 24];

float tempObjeto = 0;
float tempAmbiente = 0;
float zActual = 0;
int anguloServo = 0;

float mlxMin = 0;
float mlxMax = 0;
float mlxMedia = 0;

int cols = 32;
int rows = 24;
int escala = 16;

// =======================
// CONFIGURACION ESCALA
// =======================
boolean modoAutoescala = false;

// Rango fijo para ensayos reales
float tMinFijo = 20;
float tMaxFijo = 300;

// Variables de trabajo
float frameMin = 20;
float frameMax = 35;

// =======================
// HOTSPOT
// =======================
int hotX = 0;
int hotY = 0;
float hotTemp = 0;

// =======================
// LAYOUT
// =======================
int matrizOffsetX = 0;
int matrizOffsetY = 0;

int matrizW = cols * escala;
int matrizH = rows * escala;

int panelY = matrizH + 10;
int panelH = 190;

void setup() {
  size(900, 590);
  println(Serial.list());

  puerto = new Serial(this, Serial.list()[0], 115200);
  puerto.bufferUntil('\n');

  String nombreArchivo = "datos_termicos_" +
    year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "_" +
    nf(hour(), 2) + "-" + nf(minute(), 2) + "-" + nf(second(), 2) + ".csv";

  logCSV = createWriter(nombreArchivo);

  // Cabecera del CSV
  logCSV.println("timestamp,hotTemp,hotX,hotY,tempObjeto,tempAmbiente,zActual,anguloServo,mlxMin,mlxMax,mlxMedia");
  logCSV.flush();

  textSize(16);
  smooth();
}

void draw() {
  background(0);

  calcularRangoVisual();

  dibujarMatriz();
  dibujarHotspot();
  dibujarBarraTermica();
  dibujarPanelTexto();
}

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

      calcularRangoVisual();
      guardarFilaCSV();
    }
  } 
  else if (partes[0].equals("TEMP")) {
    if (partes.length >= 3) {
      tempObjeto = float(partes[1]);
      tempAmbiente = float(partes[2]);
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

void calcularRangoVisual() {
  if (matriz.length == 0) return;

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
    return;
  }

  if (maxV - minV < 5.0) {
    maxV = minV + 5.0;
  }

  frameMin = lerp(frameMin, minV, 0.15);
  frameMax = lerp(frameMax, maxV, 0.15);
}

void dibujarMatriz() {
  noStroke();

  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      int i = y * cols + x;
      float temp = matriz[i];

      fill(colorTermico(temp, frameMin, frameMax));
      rect(matrizOffsetX + x * escala, matrizOffsetY + y * escala, escala, escala);
    }
  }
}

void dibujarHotspot() {
  int px = matrizOffsetX + hotX * escala + escala / 2;
  int py = matrizOffsetY + hotY * escala + escala / 2;

  noFill();
  stroke(255, 0, 0);
  strokeWeight(3);
  ellipse(px, py, escala, escala);

  stroke(255);
  strokeWeight(1);
  line(px - 6, py, px + 6, py);
  line(px, py - 6, px, py + 6);

  noStroke();
  fill(255, 0, 0);
  ellipse(px, py, 5, 5);
}

color colorTermico(float valor, float minV, float maxV) {
  float n = map(valor, minV, maxV, 0, 1);
  n = constrain(n, 0, 1);

  if (n < 0.20) {
    return lerpColor(color(0, 0, 80), color(0, 0, 255), n / 0.20);
  } 
  else if (n < 0.40) {
    return lerpColor(color(0, 0, 255), color(128, 0, 255), (n - 0.20) / 0.20);
  } 
  else if (n < 0.60) {
    return lerpColor(color(128, 0, 255), color(255, 0, 255), (n - 0.40) / 0.20);
  } 
  else if (n < 0.80) {
    return lerpColor(color(255, 0, 255), color(255, 165, 0), (n - 0.60) / 0.20);
  } 
  else {
    return lerpColor(color(255, 165, 0), color(255, 0, 0), (n - 0.80) / 0.20);
  }
}

void dibujarBarraTermica() {
  int xBar = matrizW + 20;
  int yBar = 20;
  int wBar = 30;
  int hBar = matrizH - 40;

  for (int i = 0; i < hBar; i++) {
    float n = map(i, hBar, 0, 0, 1);
    float tempBarra = map(n, 0, 1, frameMin, frameMax);
    stroke(colorTermico(tempBarra, frameMin, frameMax));
    line(xBar, yBar + i, xBar + wBar, yBar + i);
  }

  noStroke();
  fill(255);
  text(nf(frameMax, 0, 1) + " C", xBar + 40, yBar + 10);
  text(nf(frameMin, 0, 1) + " C", xBar + 40, yBar + hBar);
}

void dibujarPanelTexto() {
  noStroke();
  fill(0);
  rect(0, panelY, width, panelH);

  int col1 = 15;
  int col2 = 320;
  int col3 = 620;

  int y0 = panelY + 25;
  int dy = 25;

  fill(255, 0, 0);
  text("Hotspot: " + nf(hotTemp, 0, 2) + " C", col1, y0);
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
  text("Angulo servo: " + anguloServo, col2, y0 + 4 * dy);
  text("Relacion proceso: Z = " + nf(zActual, 0, 2) + " | Hotspot = " + nf(hotTemp, 0, 2) + " C", col2, y0 + 5 * dy);

  fill(180);
  if (modoAutoescala) {
    text("Modo escala: AUTO", col3, y0);
  } else {
    text("Modo escala: FIJO", col3, y0);
  }

  fill(255);
  text("Escala min: " + nf(frameMin, 0, 1) + " C", col3, y0 + 3 * dy);
  text("Escala max: " + nf(frameMax, 0, 1) + " C", col3, y0 + 4 * dy);
}

color colorSegunTemperatura(float t) {
  if (t < 80) return color(255);
  if (t < 150) return color(255, 200, 0);
  return color(255, 0, 0);
}

void guardarFilaCSV() {
  if (!guardarDatos || logCSV == null) return;

  String timestamp = year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " +
                     nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);

  logCSV.println(
    timestamp + "," +
    hotTemp + "," +
    hotX + "," +
    hotY + "," +
    tempObjeto + "," +
    tempAmbiente + "," +
    zActual + "," +
    anguloServo + "," +
    mlxMin + "," +
    mlxMax + "," +
    mlxMedia
  );

  logCSV.flush();
}

void keyPressed() {
  if (key == 'a' || key == 'A') {
    modoAutoescala = !modoAutoescala;
  }
}

void exit() {
  if (logCSV != null) {
    logCSV.flush();
    logCSV.close();
  }
  super.exit();
}
