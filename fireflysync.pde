import processing.opengl.*;
import javax.media.opengl.*; 
/* -*- Mode: Java; -*- */
/**
 * <p>Simulation of spontaneous firefly synchronization.  See <a href="http://tinkerlog.com/2007/05/11/synchronizing-fireflies/">Synchronizing Fireflies</a> and <a
 * href="http://www.docomoeurolabs.de/pdf/publications/2006/2006_WSL_Firefly_Synchronization_Ad_Hoc_Networks.pdf">Firefly
 * Synchronization in Ad Hoc Networks</a>.
 * 
 * <p><a href="http://lemonodor.com/">John Wiseman</a><br>
 *
 * 7/22/2007
 * 
 */

 

// Some sim parameters.
int NUMFLIES = 400;
float NEIGHBORDISTANCE2D = 90;
float NEIGHBORDISTANCE3D = 180;
int depth = 600;
int FPS = 30;

// Sim state.
FireflySwarm swarm;
float neighborDistance;
boolean paused = false;

// User Interface.
PushButtonCluster cluster1, cluster2;
Button resetButton;
StripChart syncChart;


void setup () {
    size(800, 600, OPENGL);

    frameRate(FPS);
    colorMode(RGB, 255, 255, 255, 100);
    noStroke();

    swarm = new FireflySwarm(NUMFLIES);

    create_ui();

    PGraphicsOpenGL pgl;
    GL gl; 
    pgl = (PGraphicsOpenGL) g;
    gl = pgl.gl; 
    pgl.beginGL();

    // This fixes the overlap issue
    gl.glDisable(GL.GL_DEPTH_TEST);

    // Turn on the blend mode
    gl.glEnable(GL.GL_BLEND);

    // Define the blend mode
    gl.glBlendFunc(GL.GL_SRC_ALPHA,GL.GL_ONE);

    pgl.endGL(); 

    setFullScreen(true);
    setResolution(800, 600);
    createFullScreenKeyBindings();
}


void create_ui () {
    PFont font = loadFont("AndaleMono-12.vlw");
    
    // An unlit red and a lit red foe the buttons.
    color bcolor = color(118, 7, 4);
    color hbcolor = color(198, 16, 10);
    PushButton b1, b2;

    // Order/Chaos buttons.
    cluster2 = new PushButtonCluster();
    b1 = new PushButton(cluster2, 15, 5, 35, 25, bcolor, hbcolor, font, "ORD",
                        this, "setOrdered");
    new PushButton(cluster2, 63, 5, 35, 25, bcolor, hbcolor, font, "CHA",
                   this, "setChaotic");
    // Default to order.
    b1.press();
    
    // 2D/3D buttons.
    cluster1 = new PushButtonCluster();
    b1 = new PushButton(cluster1, 118, 5, 25, 25, bcolor, hbcolor, font, "2",
                        this, "set2D");
    new PushButton(cluster1, 155, 5, 25, 25, bcolor, hbcolor, font, "3",
                   this, "set3D");
    // Default to 2D.
    b1.press();

    // The reset button.
    resetButton = new Button(201, 5, 35, 25, color(200), color(255), font, "RES",
                             this, "doReset");
    resetButton.labelColor = color(0);

    // The sync strip chart.
    syncChart = new StripChart(267, 5, 700 - 267 - 15, 25);
}


void draw () {
    // Draw the swarm.
    if (!paused) {
        swarm.run();
    }

    // This bit of code ensures that the GUI always appears on top of
    // the fireflies. From <http://www.flight404.com/blog/?p=71>.
    GL gl; 
    PGraphicsOpenGL pgl;
    pgl = (PGraphicsOpenGL) g;
    gl = pgl.gl; 
    gl.glClear(GL.GL_DEPTH_BUFFER_BIT);

    // Draw the UI.
    cluster1.update();
    cluster2.update();
    resetButton.update();
    cluster1.display();
    cluster2.display();
    resetButton.display();
    syncChart.display();

    // Update the sync strip chart at 5 Hz.
    if (frameCount % 6 == 0) {
        syncChart.addValue(-swarm.power_stddev());
    }
}


// Called by the 2 button.
void set2D () {
    int margin = 20;
    int n = (int) sqrt(NUMFLIES);
    int d = (width - margin) / n;
    int slop = (height - margin) - (d * n);

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            int idx = j + n * i;
            Firefly f = swarm.fireflies[idx];
            f.position = new Vector3D(((int) (j * d)) + margin + slop / 2,
                                      ((int) (i * d)) + margin + slop / 2);
            f.is3D = false;
        }
    }
    
    neighborDistance = NEIGHBORDISTANCE2D;
}

// Called by the 3 button.
void set3D () {
    for (int i = 0; i < swarm.fireflies.length; i++) {
        Firefly f = swarm.fireflies[i];
        f.position = new Vector3D(random(width), random(height), random(depth));
        f.is3D = true;
    }

    neighborDistance = NEIGHBORDISTANCE3D;
}


// Called by the ORD button. I thought about forcing the flies onto a
// lattice in this method instead of set2D, but I like the current
// behavior.

void setOrdered () {
    for (int i = 0; i < swarm.fireflies.length; i++) {
        Firefly f = swarm.fireflies[i];
        f.mobile = false;
    }
}

// Called by the CHA button.
void setChaotic () {
    for (int i = 0; i < swarm.fireflies.length; i++) {
        Firefly f = swarm.fireflies[i];
        f.mobile = true;
    }
}

// Called by the RES button.  Doesn't clear the sync chart because I
// just like the way it looks now.
void doReset () {
    for (int i = 0; i < swarm.fireflies.length; i++) {
        Firefly f = swarm.fireflies[i];
        f.reset();
    }
}


class Firefly {
    int potential = 0;
    int threshold = FPS * 10;  // Flashing period of approx. 10 s.
    PImage img;
    PImage msk;
    ArrayList neighbors;
    FireflySwarm swarm;

    Vector3D position;
    Vector3D vel = new Vector3D(0, 0, 0);
    boolean flashing = false;
    int flashing_start_ms = 0;
    int flashing_duration_ms = 800;
    boolean mobile = true;
    boolean is3D = false;
    float circle_phase = random(30);

    Firefly(FireflySwarm swarm_, Vector3D p, PImage img_, PImage msk_) {
        swarm = swarm_;
        position = p.copy();
        msk = msk_;
        img = img_;
        img.mask(msk);
        neighbors = new ArrayList();
        reset();
        newVelocity();
    }

    void reset () {
        flashing = false;
        potential = (int) random(300);
    }

    void newVelocity () {
        float dz;
        if (is3D) {
            dz = random(-1, 1);
        } else {
            dz= 0.0;
        }
        Vector3D v_delta = new Vector3D(random(-1, 1), random(-1, 1), dz);
        v_delta.limit(0.5);
        vel.add(v_delta);
        vel.normalize();
    }
  
    void updatePosition () {
        position.add(vel);
        if (position.x < 0 || position.x > width)
            vel.x = -vel.x;
        if (position.y < 0 || position.y > height)
            vel.y = -vel.y;
        if (position.z < 0 || position.z > depth)
            vel.z = -vel.z;

        float period = TWO_PI / (30 * 1);
        Vector3D circle_v = new Vector3D(0.5 * cos(circle_phase + frameCount * period),
                                         0.5 * sin(circle_phase + frameCount * period),
                                         0.5 * cos(circle_phase + frameCount * period - 1.0));
        position.add(circle_v);
        position.x = constrain(position.x, 0, height);
        position.y = constrain(position.y, 0, width);
        position.z = constrain(position.z, 0, depth);
        if (random(0, 1) < .1) {
            newVelocity();
        }
    }

    void update () {
        int t = (int) millis();
        if (!flashing && potential >= threshold)
        {
            flash();
        }

        if (!flashing) {
            // Potential naturally increases by 30/s.
            potential += 1;
        }
                
        if (mobile) {
            updatePosition();
        }
    }

    void gotFlashed () {
        if (flashing) {
            return;
        }

        // Seeing a neighbot flash increases our potential by 5.
        potential += 5;
    }

    void notifyNeighborsOfFlash () {
        for (int i = 0; i < neighbors.size(); i++) {
            Firefly neighbor = (Firefly) neighbors.get(i);
            neighbor.gotFlashed();
        }
    }

    void flash () {
        flashing = true;
        flashing_start_ms = (int) millis();
        notifyNeighborsOfFlash();
        // When we flash it exhausts our stored potential.
        potential = 0;
    }

    void render () {
        boolean is_flashing = flashing;

        float t = millis();
        if (flashing) {
            if (t > (flashing_start_ms + flashing_duration_ms)) {
                flashing = false;
            }
        }
        if (is_flashing) {
            int intensity = (int) (255 * sin((t - flashing_start_ms) * TWO_PI /
                                             (flashing_duration_ms * 2)));

            fill((int) (intensity * 0.8), intensity, 0);
            beginShape();
            texture(img);
            vertex(position.x - 16, position.y - 16, position.z,
                   0, 0);
            vertex(position.x + 16, position.y - 16, position.z,
                   img.width, 0);
            vertex(position.x + 16, position.y + 16, position.z,
                   img.width, img.height);
            vertex(position.x - 16, position.y + 16, position.z,
                   0, img.height);
            endShape();
        }
    }

}


class FireflySwarm {
    Firefly[] fireflies;
    PImage msk;
    PImage img;
    int runCount;

    FireflySwarm (int numFlies) {
        fireflies = new Firefly[numFlies];

        // Create an alpha masked image to be applied as the firefly's texture
        msk = loadImage("firefly-mask.gif");
        img = loadImage("firefly.gif");
        
        runCount = 0;
        for (int i = 0; i < numFlies; i++) {
            Vector3D pos = new Vector3D(random(WIDTH), random(HEIGHT), random(600));
            fireflies[i] = new Firefly(this, pos, img, msk);
        }
        precalculateNeighbors();
    }


    // This is kind of a hack.  We don't use any fancy data structure
    // to figure out which fireflies are nearby when one flashes; We
    // just recalculate everyone's nearby neighbors every second or
    // so.  It turns out that even for 400 fireflies this is really
    // fast, so at this point a fancy data structure would be a waste.
    void precalculateNeighbors ()
    {
        for (int i = 0; i < fireflies.length; i++) {
            Firefly a = fireflies[i];
            a.neighbors = new ArrayList();
        }
        for (int i = 0; i < fireflies.length; i++) {
            Firefly a = fireflies[i];
            for (int j = i + 1; j < fireflies.length; j++) {
                Firefly b = fireflies[j];
                if (a.position.distance(a.position, b.position) <= neighborDistance) {
                    a.neighbors.add(b);
                    b.neighbors.add(a);
                }
            }
        }
    }


    void run () {
        background(0);
        noStroke();

        for (int i = 0; i < fireflies.length; i++) {
            fireflies[i].update();
        }
        
        Arrays.sort(fireflies, new ZOrderer());

        for (int i = 0; i < fireflies.length; i++) {
            fireflies[i].render();
        }
        
        runCount++;
        if (runCount > 30*1) {
            precalculateNeighbors();
            runCount = 0;
        }
    }

    // Calculates the average instantaneous power of the swarm.  Sort
    // of.  Since we're really using this as part of our measurement
    // of the degree to which the swarm is synchronized, we want a
    // power value of 0 to be considered "close" to the maximum power
    // value.  So We actually compute the average distance of current
    // power to max power/2.  Too tricky.
    float average_power () {
        float sum = 0.0;
        int n = fireflies.length;
        for (int i = 0; i < n; i++) {
            int v = fireflies[i].potential;
            if (v > 150) {
                v = 300 - v;
            }
            sum += v;
        }
        return sum / n;
    }
    
    
    // Calculates the standard deviation of the instantaneous power of
    // each fly in the swarm.  But see above.
    float power_stddev () {
        float sum = 0.0;
        int n = fireflies.length;
        float avg = average_power();
        for (int i = 0; i < n; i++) {
            int v = fireflies[i].potential;
            if (v > 150) {
                v = 300 - v;
            }
            sum += (v - avg) * (v - avg);
        }
        return sum / n;
    }
}

public class ZOrderer implements Comparator {
    public int compare (Object a, Object b) {
        if (((Firefly) a).position.z > ((Firefly) b).position.z) {
            return 1;
        } else {
            return -1;
        }
    }
}


public class Vector3D {
    public float x;
    public float y;
    public float z;
    
    Vector3D(float x_, float y_, float z_) {
        x = x_; y = y_; z = z_;
    }
    
    Vector3D(float x_, float y_) {
        x = x_; y = y_; z = 0f;
    }
    
    Vector3D() {
        x = 0f; y = 0f; z = 0f;
    }
    
    void setX(float x_) {
        x = x_;
    }
    
    void setY(float y_) {
        y = y_;
    }
    
    void setZ(float z_) {
        z = z_;
    }
    
    void setXY(float x_, float y_) {
        x = x_;
        y = y_;
    }
    
    void setXYZ(float x_, float y_, float z_) {
        x = x_;
        y = y_;
        z = z_;
    }
    
    void setXYZ(Vector3D v) {
        x = v.x;
        y = v.y;
        z = v.z;
    }

    public float magnitude() {
        return (float) Math.sqrt(x*x + y*y + z*z);
    }
    
    public Vector3D copy() {
        return new Vector3D(x,y,z);
    }
    
    public Vector3D copy(Vector3D v) {
        return new Vector3D(v.x, v.y,v.z);
    }
    
    public void add(Vector3D v) {
        x += v.x;
        y += v.y;
        z += v.z;
    }
    
    public void sub(Vector3D v) {
        x -= v.x;
        y -= v.y;
        z -= v.z;
    }
    
    public void mult(float n) {
        x *= n;
        y *= n;
        z *= n;
    }
    
    public void div(float n) {
        x /= n;
        y /= n;
        z /= n;
    }
    
    public void normalize() {
        float m = magnitude();
        if (m > 0) {
            div(m);
        }
    }

    public void limit(float max) {
        if (magnitude() > max) {
            normalize();
            mult(max);
        }
    }

    public float heading2D() {
        float angle = (float) Math.atan2(-y, x);
        return -1*angle;
    }

    public Vector3D add(Vector3D v1, Vector3D v2) {
        Vector3D v = new Vector3D(v1.x + v2.x,v1.y + v2.y, v1.z + v2.z);
        return v;
    }
    
    public Vector3D sub(Vector3D v1, Vector3D v2) {
        Vector3D v = new Vector3D(v1.x - v2.x,v1.y - v2.y,v1.z - v2.z);
        return v;
    }
    
    public Vector3D div(Vector3D v1, float n) {
        Vector3D v = new Vector3D(v1.x/n,v1.y/n,v1.z/n);
        return v;
    }
    
    public Vector3D mult(Vector3D v1, float n) {
        Vector3D v = new Vector3D(v1.x*n,v1.y*n,v1.z*n);
        return v;
    }
    
    public float distance (Vector3D v1, Vector3D v2) {
        float dx = v1.x - v2.x;
        float dy = v1.y - v2.y;
        float dz = v1.z - v2.z;
        return (float) Math.sqrt(dx*dx + dy*dy + dz*dz);
    }
    
}





