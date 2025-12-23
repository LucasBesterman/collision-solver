import java.util.Arrays;

final int numParticles = 30_000;
final int substeps = 1;

final float density = 0.33;
final float speed = 0.08;
final float gravity = 0.0001;
final float restitution = 0.99999;

final boolean showDensityField = false;
final boolean showParticles = true;

float diameterSq;
float diameter;
float radius;
int cols, rows;

int[][] grid;
int[] gridCount;

Particle[] particles;

PImage circleSprite;

boolean active = true;
boolean showKinetic = false;

void setup() {
  //size(800, 800);
  fullScreen(P2D);
  colorMode(HSB);
  textAlign(LEFT, TOP);
  
  diameterSq = width * height / float(numParticles) * density;
  diameter = sqrt(diameterSq);
  radius = diameter / 2;
  cols = ceil(width / diameter);
  rows = ceil(height / diameter);
  
  grid = new int[cols * rows][];
  gridCount = new int[cols * rows];
  for (int i = 0; i < cols * rows; i++) grid[i] = new int[4];
  
  float scaledSpeed = speed * radius;
  
  particles = new Particle[numParticles];
  for (int i = 0; i < numParticles; i++) {
    PVector pos = new PVector(random(radius, width-radius), random(radius, height-radius));
    PVector vel = PVector.random2D().mult(scaledSpeed);
    color particleColor = color(random(255), random(128, 255), random(128, 255));
    
    //float theta = atan2(pos.x - width/2, pos.y - height/2) + PI;
    //color particleColor = color(theta * 255 / TAU, random(128,255), random(128,255));
    
    particles[i] = new Particle(pos, vel, particleColor);
  }
  
  int d = ceil(diameter);
  PGraphics pg = createGraphics(d, d);
  pg.beginDraw();
  pg.noStroke();
  pg.fill(255);
  pg.circle(d / 2, d / 2, diameter);
  pg.endDraw();
  circleSprite = pg.get();
}

void draw() {
  if (active) for (int n = 0; n < substeps; n++) update();
  
  if (showDensityField) {
    int factor = 5;
    int d_cols = cols / factor;
    int d_rows = rows / factor;
    
    float[][] dens = new float[d_cols][d_rows];
    
    for (int x = 0; x < d_cols; x++) {
      for (int y = 0; y < d_rows; y++) {
        int sum = 0;
        
        for (int i = 0; i < factor; i++) {
          for (int j = 0; j < factor; j++) {
            int ox = x * factor + i;
            int oy = y * factor + j;
            if (ox < cols && oy < cols) sum += gridCount[ox + oy * cols];
          }
        }
        
        dens[x][y] = sum / sq(factor);
      }
    }
    
    loadPixels();
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        int px = x * d_cols / width;
        int py = y * d_rows / height;
        pixels[x + y*width] = color(dens[px][py] * 100 / density);
      }
    }
    updatePixels();
  } else background(0);
  
  if (showParticles) {
    for (Particle p : particles) {
      if (showKinetic) {
        float speedSq = p.vel.magSq();
        tint(160, 200, speedSq * 255 + 64);
      } else tint(p.particleColor);
      image(circleSprite, p.pos.x - radius, p.pos.y - radius);
    }
  }
  
  fill(0);
  noStroke();
  rect(0, 0, 40, 15);
  fill(255);
  text(frameRate, 0, 0);
}

void mouseDragged() {
  float vx = mouseX - pmouseX;
  float vy = mouseY - pmouseY;
  
  int mx = floor(mouseX / diameter);
  int my = floor(mouseY / diameter);
  
  for (int dx = -5; dx <= 5; dx++) {
    for (int dy = -5; dy <= 5; dy++) {
      int x = mx + dx;
      int y = my + dy;
      if (x < 0 || y < 0 || x >= cols || y >= rows) continue;
      
      int[] cell = grid[x + y * cols];
      int count = gridCount[x + y * cols];
      
      for (int i = 0; i < count; i++) {
        Particle p = particles[cell[i]];
        float dxm = p.pos.x - mouseX;
        float dym = p.pos.y - mouseY;
        float distSq = dxm * dxm + dym * dym;
        
        if (distSq < 400) {
          float str = radius * 0.1 / (sqrt(distSq) + 1);
          p.vel.x += vx * str;
          p.vel.y += vy * str;
        }
      }
    }
  }
}

void keyPressed() {
  if (key == ' ') active = !active;
  else if (key == 'k') showKinetic = !showKinetic;
}

void update() {
  Arrays.fill(gridCount, 0);
  
  for (int i = 0; i < numParticles; i++) {
    Particle p = particles[i];
    p.update();
    
    int px = floor(p.pos.x / diameter);
    int py = floor(p.pos.y / diameter);
    int index = px + py * cols;
    int count = gridCount[index];
    
    if (count < 4) {
      grid[index][count] = i;
      gridCount[index]++;
    }
  }
  
  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      checkCollisions(x, y, x, y);
      if (x < cols-1) {
        if (y > 0) checkCollisions(x, y, x+1, y-1);
        checkCollisions(x, y, x+1, y);
        if (y < rows-1) checkCollisions(x, y, x+1, y+1);
      }
      if (y > 0) checkCollisions(x, y, x, y-1);
    }
  }
}

void checkCollisions(int x1, int y1, int x2, int y2) {
  int cellIndex1 = x1 + y1 * cols;
  int cellIndex2 = x2 + y2 * cols;
  boolean selfCheck = cellIndex1 == cellIndex2;
  
  int[] cell1 = grid[cellIndex1];
  int[] cell2 = grid[cellIndex2];
  
  for (int i = 0; i < gridCount[cellIndex1]; i++) {
    int particleIndex1 = cell1[i];
    Particle p1 = particles[particleIndex1];
    
    for (int j = 0; j < gridCount[cellIndex2]; j++) {
      int particleIndex2 = cell2[j];
      Particle p2 = particles[particleIndex2];
      
      if (particleIndex1 == particleIndex2) continue;
      if (selfCheck && particleIndex1 < particleIndex2) continue;
      
      PVector sep = PVector.sub(p1.pos, p2.pos);
      float distSq = sep.magSq();
      if (distSq >= diameterSq) continue;
      
      float dist = sqrt(distSq);
      sep.div(dist);
      
      float overlap = diameter - dist;
      PVector correction = PVector.mult(sep, overlap / 4);
      p1.pos.add(correction);
      p2.pos.sub(correction);
      
      float dot = PVector.dot(PVector.sub(p1.vel, p2.vel), sep);
      PVector normalVel = PVector.mult(sep, dot * restitution);
      p1.vel.sub(normalVel);
      p2.vel.add(normalVel);
    }
  }
}

class Particle {
  PVector pos, vel;
  color particleColor;
  
  Particle(PVector pos, PVector vel, color particleColor) {
    this.pos = pos;
    this.vel = vel;
    this.particleColor = particleColor;
  }
  
  void update() {
    vel.add(0, gravity);
    pos.add(PVector.div(vel, substeps));
    
    if (pos.x < radius || pos.x > width-radius) {
      vel.x *= -restitution;
      pos.x = constrain(pos.x, radius, width-radius);
    }
    
    if (pos.y < radius || pos.y > height-radius) {
      vel.y *= -restitution;
      pos.y = constrain(pos.y, radius, height-radius);
    }
  }
}
