/* -*- Mode: Java; -*- */

import java.lang.reflect.*;


boolean locked = false;


// Not as general as it could be.
class StripChart {
    int x, y;
    int width, height;
    float[] values;
    float min, max;
    int start = 0, end = 0;
    int numValues = 0;
    float prevValue;

    StripChart (int x_, int y_, int width_, int height_) {
        x = x_;
        y = y_;
        width = width_;
        height = height_;
        values = new float[width_ - 2];
    }

    void addValue (float v) {
        if (numValues > 0) {
            v = 0.95 * prevValue + 0.05 * v;
        }
        prevValue = v;

        if (numValues >= width) {
            // Buffer is full;
            values[end] = v;
            start = (start + 1) % values.length;
            end = (end + 1) % values.length;
        } else {
            values[end] = v;
            end = (end + 1) % values.length;
            numValues += 1;
        }
        if (numValues == 1) {
            min = v;
            max = 0;
        } else {
            if (v < min) {
                min = v;
            } else if (v > max) {
                max = 0;
            }
        }
    }
    
    void display () {
        noFill();
        rectMode(CORNER);
        stroke(20);
        rect(x, y, width, height);
        
        if (numValues == 0) {
            return;
        }

        float mmin = min - .0001;
        float delta = max - mmin;
        for (int i = 0; i < numValues; i++) {
            int idx = (start + i) % values.length;
            int gx = x + i + 1;
            int gy = y + height - 2 - (int) (((values[idx] - mmin) / delta) * (height - 2));
            stroke((int) (255 * (((float) i) / numValues)));
            // Using point here doesn't work, and I do not know why.
            // Bad interaction with the 3D stuff?
            rect(gx, gy, 1, 0);
        }
    }
}


class Button {
    int x, y;
    int width, height;
    color basecolor, highlightcolor;
    color currentcolor;
    boolean over = false;
    PFont font;
    color labelColor = color(255);
    String label;
    Object target;
    String method;
    boolean pressed = false;

    Button (int x_, int y_, int width_, int height_,
            color basecolor_, color highlightcolor_,
            PFont font_, String label_,
            Object target_, String method_) {
        x = x_;
        y = y_;
        width = width_;
        height = height_;
        basecolor = basecolor_;
        highlightcolor = highlightcolor_;
        font = font_;
        label = label_;
        target = target_;
        method = method_;
    }

    void update () {
        if (over() && beingPressed()) {
            press();
        } else {
            unpress();
        }
        if (pressed) {
            currentcolor = highlightcolor;
        } else {
            currentcolor = basecolor;
        }
    }

    void display () {
        stroke(255);
        fill(currentcolor);
        rect(x, y, width, height);
        fill(labelColor);
        stroke(255);
        textFont(font);
        textAlign(LEFT, CENTER);
        float theight = textAscent() + textDescent();
        float twidth = textWidth(label);
        text(label, x + (width / 2) - (twidth / 2), y + height / 2);
    }

    void notifyTarget () {
        Class[] parameters;
        parameters = new Class[] {};
        try {
            Method targetMethod = target.getClass().getMethod(method, parameters);
            try {
                targetMethod.invoke(target, new Object[] {});
            } catch (InvocationTargetException e) {
                println("PushButton error: Failed to invoke method '" + method + "' on " + target);
            } catch (IllegalAccessException e) {
                println("PushButton error: Failed to invoke method '" + method + "' on " + target);
            }
        } catch (NoSuchMethodException e) {
            println("PushButton error: Object " + target + " has no method '" + method + "'");
        }
    }

    void press () {
        pressed = true;
    }

    void unpress () {
        if (pressed) {
            notifyTarget();
        }
        pressed = false;
    }
    
    boolean beingPressed () {
        if (over() && mousePressed) {
            locked = true;
            return true;
        } else {
            locked = false;
            return false;
        }
    }

    boolean over () {
        if (overRect(x, y, width, height)) {
            over = true;
            return true;
        } else {
            over = false;
            return false;
        }
    }
}

class PushButtonCluster {
    ArrayList buttons;

    PushButtonCluster () {
        buttons = new ArrayList();
    }

    void add (PushButton b) {
        buttons.add(b);
    }

    void update () {
        for (int i = 0; i < buttons.size(); i++) {
            PushButton b = (PushButton) buttons.get(i);
            b.update();
        }
    }

    void display () {
        for (int i = 0; i < buttons.size(); i++) {
            PushButton b = (PushButton) buttons.get(i);
            b.display();
        }
    }

    void pressed (PushButton b) {
        for (int i = 0; i < buttons.size(); i++) {
            PushButton ob = (PushButton) buttons.get(i);
            if (ob != b) {
                ob.unpress();
            }
        }
    }
}



class PushButton extends Button {
    PushButtonCluster cluster;

    PushButton (PushButtonCluster cluster_, int x_, int y_, int width_, int height_,
                color basecolor_, color highlightcolor_, PFont font_, String label_,
                Object target_, String method_) {
        super(x_, y_, width_, height_,
              basecolor_, highlightcolor_,
              font_, label_,
              target_, method_);
        cluster = cluster_;
        cluster.add(this);
    }

    void press () {
        boolean was_pressed = pressed;
        cluster.pressed(this);
        super.press();
        if (!was_pressed) {
            notifyTarget();
        }
    }

    void unpress () {
        pressed = false;
    }

    void update () {
        if (over() && beingPressed()) {
            press();
        }
        if (pressed) {
            currentcolor = highlightcolor;
        } else {
            currentcolor = basecolor;
        }
    }

}

boolean overRect (int x, int y, int width, int height) {
    if (mouseX >= x && mouseX <= x + width &&
        mouseY >= y && mouseY <= y + height) {
        return true;
    } else {
        return false;
    }
}


