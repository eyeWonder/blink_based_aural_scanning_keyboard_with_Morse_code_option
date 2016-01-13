/* aural_keyboard: 2015-12-19 : ylh
 on github.com as blink_based_aural_scanning_keyboard_with_Morse_code_option
 
 based on blink_opencv3 20150219 - 20150225
 see manual file for Manual
 
 Phases: (when pressed)
 0 - test
 1 - reset eye position, waiting for detection of left eye
 2 - when, 1 pressed, registered 'normal' eye configuration
 3 - 'yes' registered
 4 - 'no' registered; now loop around waiting to go to aural kb
 5 - aural keyboard/ mail
 9 - go to Morse mode ( "......" 6 dits get back to scanning mode
 
 mode: 0=regular keyboard; 1=browser; 2=email
 inputType: 0 = regular aural, 1 = Morse
 */

import gab.opencv.*;
import processing.video.*;
import java.awt.*;
import ddf.minim.*;
import ddf.minim.ugens.*;
import org.opencv.imgproc.Imgproc;
import org.opencv.core.Mat;
import org.opencv.core.Core.MinMaxLocResult;
import org.opencv.core.Core;

import java.io.*;

boolean testing = false;  // jump to new code in 'test'
boolean useOldcode = false; // testing fragments

boolean useWebcam = false; // use webcam (true) or eye cam (false)
boolean debug = false;
boolean useColor = false;
boolean useGoogle = false;
boolean useBrowser = false;

// 0 - waiting; when both eyes closed, triggered alarmStartTime ->1
// 1 && alarmStartTime > x msec, buzzAlarm.on -> 2
// 2 && both eyes open -> 0

// when announceon = false, no announcement is made, used with sound on to practice blink
boolean announceon = true;  
// soundon - beeps on Eye Up
boolean soundon = false;
// voiceon - voice feedback on select
boolean voiceon = true;
// pause operations
boolean pause = false;
boolean callbellReady = true;

// enum for the variable 'mode'
final int REGULAR = 0;  
final int BROWSER = 1;
final int EMAIL = 2;
int mode = REGULAR; // 0=regular aural keyboard; 1=browser; 2=emailpp

// enum for the variable 'inputType'
final int MORSE = 1; 
int inputType = REGULAR;

// morse - is current scene MARK or Space?
boolean MARK = false;

// message store
final int MaxLines = 16;
String[] textlines = new String[MaxLines+1];
int currentLine = 0;


final int FRAME_RATE = 15; // normal running frame rate to return to, from slower resting state

int units = 400;  // morse units
final int seconds = 1000;

int pauseFor;
boolean showCountDown = false; // pause countdown indicator
int alarmThreshold = 9*seconds; 

int SCALE = 1;

Minim gMinim;
AudioPlayer[] sounds;

// audio alarms
Buzzer buzzDash, buzzDot, buzzAlarm;

Capture video;
OpenCV opencv, opencv2;
import java.awt.Robot;
import java.awt.event.KeyEvent;

Robot robot;

int phase=1; //lastTime;
// int iters = 0;
//ClickButton clk;

// phase 1
String instruction = "1=Reset  2=register 'Normal'  3=register 'Eyes Up'  4=register 'Eyes Down' 5=Run";
String instruction2 = "a=announce p=pause s=sound v=voice feedback j=slower k=faster Shift-R=ready alarm";

Rectangle ROI = new Rectangle(0, 0, 0, 0);
Rectangle foundROI = new Rectangle(0, 0, 0, 0);
Rectangle roiLeft = new Rectangle(0, 0, 0, 0);
Rectangle roiRight = new Rectangle(0, 0, 0, 0);
PImage IMsource, IMnormal, IMyes, IMno; 

int screenWidth = 1240;
int screenHeight = 880;

// translating coordinates to here
int offsetX = 300, offsetY = 440;

// variables
Histogram normalHist, yesHist, sourceHist;
Mat normalMat, yesMat, noMat, sourceMat, Mroi, normalRes, yesRes, noRes;
int selected = 0;

// below for eye camera use (see test_borescope.pde)
// i.e. useWebcam == false
int camWidth = 160;
int camHeight = 120;// 128;
PImage[] imL;
Mat[] matL;
Mat[] res;

void setup() {

  if ( testing ) {
    testSetup();
    return;
  }

  textlines[0]="";
  /* test new fragments of speech here */
  if ( true  ) {
    textlines[0] = "The quick brown fox jumps over the lazy dog";
    textlines[1] = "Please turn on the TV";
    textlines[2] = "Thank you";
    currentLine = 2;
    readIt();
    if (false) exit();
  }   

  //size(640, 480);
  size(screenWidth, screenHeight);


  buzzDash = new Buzzer( 1000, 0.1 );
  buzzDot = new Buzzer( 1200, 0.1 ); 
  buzzAlarm = new Buzzer( 1200, 0.8 );  

  if ( debug ) ListCameras();

  if ( useWebcam ) {
    video = new Capture(this, 640/SCALE, 480/SCALE);
  } else {
    video = new Capture(this, "name=USB2.0_Camera,size="  //U cam webcam
    //video = new Capture(this, "name=USB 2.0 Camera,size="  //webcam
    //video = new Capture(this, "name=USB 2.0 PC Cam,size="  // borescope
    + camWidth + "x" 
      + camHeight + ",fps=30" ); 
    // video = new Capture(this, "name=USB 2.0 Camera,size=80x64,fps=30");//name=USB 2.0 Camera,size=320x256,fps=15");  // using alternate camera
  }

  opencv = new OpenCV(this, 640/SCALE, 480/SCALE);
  //opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE); 
  opencv.loadCascade( OpenCV.CASCADE_EYE );
  opencv.useGray(); 

  if ( useWebcam == false ) {
    matL = new Mat[10];
    res = new Mat[10];
    imL = new PImage[10];
  }
  video.start();

  /*
  clk = new ClickButton(0, false);
   clk.debounceTime = 10;
   clk.multiclickTime = 800;
   clk.longClickTime = 1500;
   */

  try {
    robot = new Robot();
  } 
  catch (java.awt.AWTException ex) { 
    println("Problem initializing AWT Robot: " + ex.toString());
  }

  doCBInit();

  //launchMail();

  frameRate(FRAME_RATE);
}

void draw() {

  if (testing) {
    testDraw();
    return;
  }

  scale(SCALE);
  // timed operations checked here
  buzzDash.loop();
  buzzDot.loop();
  buzzAlarm.loop();
  checkPause();

  fill(0, 0, 0);
  rect(0, 0, width, height);
  noFill();

  displayText(); // display in the main frame

  pushMatrix(); 
  translate (offsetX, offsetY);  

  switch( phase ) {
  case 0:
    doMail();
    break;
  case 1:
    initPhase1();
    doPhase1();
    break;
  case 2:
    doPhase2();
    break;
  case 3:
    doPhase3();
    break;
  case 4:
    doPhase4();
    break;
  case 5:
    doPhase5();
    break;
  }

  /*
  if ( clk.clicks != 0 ) 
   println ( iters, ":: ", clk.clicks );
   iters++;
   */

  popMatrix();
}

void keyPressed() {

  if ( testing ) return;

  switch( phase ) {
  case 0:
    //switchToAlpine();
    //type(key);
    //doAlpine();
    break;
  case 1:  // in phase 1, therefore '2' is pressed
    stroke(0);

    IMnormal = get( (SCALE*foundROI.x)+ offsetX, (SCALE*foundROI.y) + offsetY, SCALE*foundROI.width, SCALE*foundROI.height);
    if ( useWebcam ) {
      IMsource = trans2( IMnormal );
      IMsource.save("normal.jpg");

      opencv2 = new OpenCV(this, "normal.jpg", useColor);
      opencv2.setGray(opencv2.getR().clone());
      Imgproc.morphologyEx(opencv2.getGray(), opencv2.getGray(), Imgproc.MORPH_GRADIENT, new Mat());
      normalMat = opencv2.getGray();
    } else {
      IMsource = get( SCALE*ROI.x+offsetX, SCALE*ROI.y+offsetY, SCALE*ROI.width, SCALE*ROI.height );
      IMsource.save("normal.jpg");
      process(0, IMsource);
    }
    phase = 2;  
    break;
  case 2:  // in phase 2 therefore '3' is pressed
    stroke(0);
    IMnormal = get( SCALE*foundROI.x+offsetX, SCALE*foundROI.y+offsetY, SCALE*foundROI.width, SCALE*foundROI.height);
    if ( useWebcam ) {
      IMsource = trans2( IMnormal ); 
      IMsource.save("yes.jpg");

      opencv2 = new OpenCV(this, "yes.jpg", useColor);
      opencv2.setGray(opencv2.getR().clone());
      Imgproc.morphologyEx(opencv2.getGray(), opencv2.getGray(), Imgproc.MORPH_GRADIENT, new Mat());
      yesMat = opencv2.getGray();
    } else {
      IMsource = get( SCALE*ROI.x+offsetX, SCALE*ROI.y+offsetY, SCALE*ROI.width, SCALE*ROI.height );
      IMsource.save("yes.jpg");
      process(1, IMsource);
    }
    phase = 3;  
    break;
  case 3:
    stroke(0);
    IMnormal = get( SCALE*foundROI.x+offsetX, SCALE*foundROI.y+offsetY, SCALE*foundROI.width, SCALE*foundROI.height );

    if ( useWebcam) {
      IMsource = trans2( IMnormal ); 
      IMsource.save("no.jpg");

      opencv2 = new OpenCV(this, "no.jpg", useColor);
      opencv2.setGray(opencv2.getR().clone());
      Imgproc.morphologyEx(opencv2.getGray(), opencv2.getGray(), Imgproc.MORPH_GRADIENT, new Mat());
      noMat = opencv2.getGray();

      /* changed
       foundROI.x-=10; 
       foundROI.y-=10; 
       foundROI.width +=20;
       foundROI.height+=20;
       */
    } else {
      IMsource = get( SCALE*ROI.x+offsetX, SCALE*ROI.y+offsetY, SCALE*ROI.width, SCALE*ROI.height );
      IMsource.save("no.jpg");
      process(2, IMsource);
    }
    phase = 4;  
    break;
  case 4:
    // phase = no activity; just loop and wait
    break;
  case 5:  
    // ignore keystrokes if in email
    if ( mode==REGULAR ) { 

      if ( !pause && key == ' ') {
        selected = 1;
        print('*');
        if ( soundon ) buzzDot.on(50);
        if (inputType == REGULAR)
          doCB();
        else doMorse();
      } 
      if (key == 'a' ) announceon = !announceon;    
      if (key == 'p' ) { 
        if ( !pause ) pauseFor(0, false);
        else pause();
        /*
        if ( pause && inputType == MORSE ) {
         firstTimeMorse = millis();
         morseStr = "";
         }
         pause = !pause;  
         if (pause) whenPaused = millis();
         lastPresented = millis()+2*seconds;
         frameRate(FRAME_RATE);
         */
      }   
      if (key == 's' ) soundon = !soundon;
      if (key == 'v' ) voiceon = !voiceon;
      if (key == 'k' ) faster();
      if (key == 'j' ) slower();
      if (key == 'R' ) callbellReady = !callbellReady;
      if (key == 'd' ) deleteChar(true);
    }
    break;
  case 6: 
    break;
  }
  switch( key ) {
  case '1':
    phase = 1;
    mode=REGULAR;
    break;
  case '2':
    phase = 2;
    break;
  case '3':
    phase =3;
    break;
  case '4':
    phase =4;
    break;
  case '5':
    phase =5;
    break;
  case '0':
  case 't':
  case 'T':
    // phase = 0;
    break;
  }
}

void doPhase5() {

  showInstruction();
  displayBuffer();

  if ( pause ) {
    textSize(30);
    fill( 255, 0, 0 );
    text( "PAUSED", 260, 40 );
    //if ( prevItem.equals("pause") ) {
    if (showCountDown) {
      text( (pauseFor - (millis() - whenPaused))/1000, 380, 40 );
    }
    return;
  }

  noFill();

  opencv.loadImage(video);
  image(video, 0, 0 );

  fill(0, 0, 0); 
  stroke(0, 0, 0);
  rect(0, 0, screenWidth, ROI.y); // blacken top
  rect(0, ROI.y+ROI.height-20, screenWidth, screenHeight); // blacken bottom

  showInstruction();
  displayBuffer();

  if (useWebcam) {
    noFill();
    strokeWeight(1);
    stroke(0, 255, 0);
    rect(foundROI.x, foundROI.y, foundROI.width, foundROI.height); 

    if ( useOldcode) {

      IMnormal = get(foundROI.x+offsetX, foundROI.y + offsetY, foundROI.width, foundROI.height);
      image( IMnormal, -300, -300 );

      opencv.releaseROI();
      opencv.setROI(foundROI.x, foundROI.y, foundROI.width, foundROI.height);
      debugROI("5old");
      Mroi = opencv.getROI().clone(); 
      opencv.releaseROI();
      //opencv.setGray(Mroi);

      // bad use of morphology
      Imgproc.morphologyEx(Mroi, Mroi, Imgproc.MORPH_GRADIENT, new Mat());

      normalRes = new Mat();  
      //inverted template/image to search
      Imgproc.matchTemplate(Mroi, normalMat, normalRes, Imgproc.TM_CCORR_NORMED);
      yesRes = new Mat();  
      Imgproc.matchTemplate(Mroi, yesMat, yesRes, Imgproc.TM_CCORR_NORMED);
      noRes = new Mat();  
      Imgproc.matchTemplate(Mroi, noMat, noRes, Imgproc.TM_CCORR_NORMED);
    } else {

      // debugROI("5");
      IMnormal = get(foundROI.x+offsetX, foundROI.y+offsetY, foundROI.width, foundROI.height);
      //image( IMnormal, -IMnormal.width, 0);
      IMsource = trans2( IMnormal ); 
      image( IMsource, -IMnormal.width, 0) ; 

      //  println("5imange:" +IMsource.width+" "+IMsource.height);

      opencv = new OpenCV( this, IMsource );
      opencv.setROI(0, 0, IMsource.width, IMsource.height);
      Mroi = opencv.getROI().clone(); 
      opencv.releaseROI();
      //opencv.setGray(Mroi);
      // DO NOT USE morphology
      //Imgproc.morphologyEx(Mroi, Mroi, Imgproc.MORPH_GRADIENT, new Mat());

      normalRes = new Mat();  
      Imgproc.matchTemplate(normalMat, Mroi, normalRes, Imgproc.TM_CCORR_NORMED);
      yesRes = new Mat();  
      Imgproc.matchTemplate(yesMat, Mroi, yesRes, Imgproc.TM_CCORR_NORMED);
      noRes = new Mat();  
      Imgproc.matchTemplate(noMat, Mroi, noRes, Imgproc.TM_CCORR_NORMED);
    }


    if ( debug ) {
      println( "normal=" + nf((float)Core.minMaxLoc(normalRes).maxVal, 0, 2)
        + " yes=" + nf((float)Core.minMaxLoc(yesRes).maxVal, 0, 2) 
        + " no=" + nf((float)Core.minMaxLoc(noRes).maxVal, 0, 2));
    }
  } else { // use eye cam
    //IMnormal = loadImage( "normal.jpg" );
    image( IMnormal, camWidth, 0 );
    image( imL[0], camWidth, camHeight );
    //IMyes = loadImage( "yes.jpg" );
    image( IMyes, camWidth*2, 0 );
    image( imL[1], camWidth*2, camHeight );
    //IMno = loadImage( "no.jpg" );
    image( IMno, camWidth*3, 0 );
    image( imL[2], camWidth*3, camHeight );

    PImage IMcurrent = get(foundROI.x+offsetX, foundROI.y + offsetY, foundROI.width, foundROI.height);
    PImage procCurrent = process( 3, IMcurrent );
    Mroi = matL[3];
    image( procCurrent, 0, camHeight );

    opencv = new OpenCV( this, procCurrent );
    opencv.setROI(0, 0, IMcurrent.width, IMcurrent.height);
    Mroi = opencv.getROI().clone(); 
    opencv.releaseROI();

    for (int i=0; i<3; i++) { 
      res[i] = new Mat();
      Imgproc.matchTemplate(matL[i], Mroi, res[i], Imgproc.TM_CCORR_NORMED);
      //Imgproc.matchTemplate(matL[i], Mroi, res[i], Imgproc.TM_CCOEFF_NORMED);

      //Imgproc.matchTemplate(matL[i], Mroi, res[i], Imgproc.TM_SQDIFF);

      noFill();
      stroke(0, 255, 0);
      strokeWeight(1);
      rect( OpenCV.pointToPVector(Core.minMaxLoc(res[i]).maxLoc).x + camWidth*(i+1), 
      OpenCV.pointToPVector(Core.minMaxLoc(res[i]).maxLoc).y + camHeight, foundROI.width, 
      foundROI.height );

      fill( 255, 0, 0 );
      text( nf((float)Core.minMaxLoc(res[i]).maxVal, 0, 2), camWidth*(i+1) + 20, camHeight*2 - 15);
    }

    normalRes = res[0];
    yesRes = res[1];
    noRes = res[2];
  }

  /* if using another coefficient
  if ( Core.minMaxLoc(yesRes).minVal < 0.5 && 
   ( Core.minMaxLoc(yesRes).minVal < Core.minMaxLoc(normalRes).minVal ) &&
   ( Core.minMaxLoc(yesRes).minVal < Core.minMaxLoc(noRes).minVal )  ) {
   //*/

  if ( Core.minMaxLoc(yesRes).maxVal > 0.6 && 
    ( Core.minMaxLoc(yesRes).maxVal > Core.minMaxLoc(normalRes).maxVal ) &&
    ( Core.minMaxLoc(yesRes).maxVal > Core.minMaxLoc(noRes).maxVal )  ) {

    if (debug) {
      fill(255, 0, 0);
      textSize(16);
      text( "normal=" + nf((float)Core.minMaxLoc(normalRes).maxVal, 0, 2)
        + " yes=" + nf((float)Core.minMaxLoc(yesRes).maxVal, 0, 2) 
        + " no=" + nf((float)Core.minMaxLoc(noRes).maxVal, 0, 2), -IMnormal.width, -40 );
    }  
    // MARK
    selected = 1;  // yes1
    fill(0, 0, 255);
    rect(0, 0, foundROI.width, foundROI.height); 
    noFill();
    //noCount =0; // reset 
    //yesCount++;
    print(".");
    if ( !MARK && ((millis()-firstTimeMorse ) > 2*seconds) ) {
      timeLapse = millis() - lastTransit;
      lastTransit = millis();
      TRANSIT = true;
      MARK = true;
    }

    if ( soundon && inputType==REGULAR ) buzzDot.on(1000);
    if ( callbellReady && ( (millis() - lastTransit) > alarmThreshold )) {
      buzzAlarm.on(5000);
      pauseFor(5000, false);
    }
  } else { 
    // NOT MARK
    if ( Core.minMaxLoc(noRes).maxVal > 0.6 && 
      ( Core.minMaxLoc(noRes).maxVal > Core.minMaxLoc(normalRes).maxVal ) &&
      ( Core.minMaxLoc(noRes).maxVal > Core.minMaxLoc(yesRes).maxVal )  ) {

      // "No" - not used yet
      selected = 2; // no
      
      pauseFor( 60000, true );  // 'no' gesture means 60s pause
      /*
       fill(255, 0, 0);
       rect(foundROI.x, foundROI.y, foundROI.width, foundROI.height); 
       noFill();
       */
      //buzzDot.on(50);
      //noCount++;
      println("XXX");
      /* YLH - use NO to reset morse buffer
       if ( inputType==MORSE ) {
       morseStr="";
       MARK = TRANSIT = false;
       wroteSpace = true; // steady state
       timeLapse = 0;
       lastTransit = millis()-3*seconds;
       }
       */
      // if ( callbellReady && ( noCount > alarmThreshold )) 
      // buzzAlarm.on(2000);
    } else { // normal
      //spaceCount++;
      //noCount = 0; // reset alarm1
      //print(" ");

      if ( MARK  && ((millis()-firstTimeMorse ) > 2*seconds) ) {  
        timeLapse = millis() - lastTransit;
        lastTransit = millis();
        TRANSIT = true;
        MARK = false;
      }
    }

    if ( soundon && inputType == REGULAR ) buzzDot.off();
  }

  if (inputType == REGULAR) {
    doCB();
  } else {
    doMorse();
  }
}

void doPhase4() {
  stroke(0, 255, 0);
  image(video, 0, 0 );
  showInstruction();  

  if ( useWebcam) {
    IMnormal = loadImage( "normal.jpg");
    image( IMnormal, - IMnormal.width, 0 ) ; //image( IMnormal, 0, 0);
    IMyes = loadImage( "yes.jpg");
    image( IMyes, - IMnormal.width, IMnormal.height ) ; //image( IMyes, 0, IMnormal.height);
    IMno = loadImage( "no.jpg");
    image( IMno, - IMnormal.width, IMnormal.height+IMyes.height ) ; //image( IMno, 0, IMnormal.height+IMyes.height);
    stroke(0, 255, 0);
    rect(ROI.x, ROI.y, ROI.width, ROI.height);
    stroke( 0, 0, 255);
    rect(  foundROI.x, foundROI.y, foundROI.width, foundROI.height );
  } else {
    IMnormal = loadImage( "normal.jpg");
    image( IMnormal, camWidth, 0 );
    image( imL[0], camWidth, camHeight );
    IMyes = loadImage( "yes.jpg" );
    image( IMyes, camWidth*2, 0 );
    image( imL[1], camWidth*2, camHeight );
    IMno = loadImage( "no.jpg" );
    image( IMno, camWidth*3, 0 );
    image( imL[2], camWidth*3, camHeight );
  }

  lastPresented = millis();
  presented = false;
  selected = 0;
  //phase = 5;
}

void doPhase3() {
  stroke(0, 255, 0);
  image(video, 0, 0 );
  showInstruction();

  IMnormal = loadImage( "normal.jpg");
  if ( useWebcam ) {
    image( IMnormal, - IMnormal.width, 0 ) ; //image( IMnormal, 0, 0);
    IMyes = loadImage( "yes.jpg");
    image( IMyes, - IMnormal.width, IMnormal.height ) ; // image( IMyes, 0, IMnormal.height);
    stroke(0, 255, 0);
    rect(ROI.x, ROI.y, ROI.width, ROI.height);
    stroke( 0, 0, 255);
    rect(  foundROI.x-2, foundROI.y-2, foundROI.width+4, foundROI.height+4 );
  } else {
    image( IMnormal, camWidth, 0 );
    image( imL[0], camWidth, camHeight );
    IMyes = loadImage( "yes.jpg" );
    image( IMyes, camWidth*2, 0 );
    image( imL[1], camWidth*2, camHeight );
  }
}
void doPhase2() {

  image(video, 0, 0 );
  showInstruction();
  IMnormal = loadImage( "normal.jpg");

  if (useWebcam) {
    image( IMnormal, - IMnormal.width, 0 ) ; //image( IMnormal, 0, 0);

    stroke(0, 255, 0);
    rect(ROI.x, ROI.y, ROI.width, ROI.height);

    stroke( 0, 0, 255);
    rect(  foundROI.x-2, foundROI.y-2, foundROI.width+4, foundROI.height+4 );
  } else {
    image( IMnormal, camWidth, 0 );
    image( imL[0], camWidth, camHeight );
  }
  //debugROI("2");
}

void doPhase1() {

  opencv.loadImage(video);
  image(video, 0, 0 );
  showInstruction();

  if ( useWebcam ) {
    ROI.width=120; 
    ROI.height = 240;
    ROI.x = 320/SCALE; // left eye
    ROI.y = 240/SCALE - ROI.height/SCALE/2; 

    boolean found = findEye( ROI );

    if ( found ) {
      if (debug) println( "1: " + foundROI.x + " " + foundROI.y + " " + foundROI.width+ " " +foundROI.height );
    }
  } else {
    ROI.x = 0;
    ROI.y = 0;
    ROI.width = camWidth;
    ROI.height = camHeight;
    foundROI.x = 10;
    foundROI.y = 10;
    foundROI.width = camWidth - 20;
    foundROI.height = camHeight - 20;
  }
}

boolean findEye( Rectangle roi ) {

  noFill();
  strokeWeight(1);
  stroke(0, 255, 0);
  rect(roi.x-roi.width, roi.y, roi.width*2, roi.height);
  line(roi.x, roi.y, roi.x, roi.y+roi.height);

  opencv.setROI(roi.x, roi.y, roi.width, roi.height);
  Rectangle[] eyes = opencv.detect();
  stroke(0, 0, 255);

  for ( int j=0; j<eyes.length; j++ ) {
    rect( eyes[j].x+roi.x-2, eyes[j].y+roi.y-2, eyes[j].width+4, eyes[j].height+4 );
    foundROI = eyes[j];
    foundROI.x += roi.x;
    foundROI.y += roi.y;
  }

  if ( eyes.length==0 ) {
    buzzDash.on(100);
    return false;
  } else {    
    return true;
  }
}

void captureEvent(Capture c) {
  c.read();
}

void displayText() {
  fill(0, 255, 0);
  textSize(24);
  int l=buffer.length();
  if ( currentLine < MaxLines && l > 40 && buffer.charAt(l-1)==' ') {
    textlines[currentLine] = buffer.substring( 0, l-1);
    currentLine++;
    buffer="";
    sayWords("line_stored");
  }
  textlines[currentLine] = buffer;
  for ( int i=0; i<=currentLine; i++ ) {  
    text( textlines[i], offsetX, 30 + i*25);
  }
  noFill();
}

void retrieveLine() {
  if (currentLine <= 0 ) return;
  currentLine--;
  buffer = textlines[currentLine];
  sayWords("line_retrieved");
}

void showInstruction() {
  textSize(14);
  fill(256, 256, 0);
  text( instruction, 10, 360 );
  text( instruction2, 10, 380 );
  noFill();
}

void displayBuffer() {
  int vs = 15, y=285;
  fill(255, 0, 0);
  textSize(30);

  text( buffer.toUpperCase().replaceAll(" ", "_"), 10, -25 );

  textSize(16);
  fill(0, 128, 128);
  if ( inputType == MORSE ) {
    text("speed is " +  Integer.toString(morseSpeed), 10, y );
    displayMorse();
  } else 
    text("speed is " +  Integer.toString(speed), 10, y );

  if ( voiceon) {
    y+=vs;
    fill(0, 128, 128);
    text( "voice feedback on", 10, y);
  }
  if ( soundon) {
    y+=vs;
    fill(0, 128, 128);
    text( "sound on", 10, y);
  }
  if ( !callbellReady) {
    y+=vs;
    fill(255, 0, 0);
    text( "alarm off", 10, y);
  }
  if ( !announceon) {
    y+=vs;
    fill(255, 0, 0);
    text( "NO ANNOUNCEMENT", 10, y);
  }
  fill(0, 128, 128);
}

void displayMorse() {
  int thisx=250, thisy=27;
  fill(255, 0, 255);
  if ( morseStr.length() ==0 ) return;
  for ( int i=0; i<morseStr.length (); i++ ) {
    if ( morseStr.charAt(i) == '.') {
      ellipse( thisx, thisy, 15, 15 );
      thisx += 20;
    } else {
      rect( thisx-7, thisy-6, 30, 12 );
      thisx += 40;
    }
  }
}

// read text from pre-loaded mp3 files
void sayWords ( String s ) {
  if ( voiceon ) {
    int i=menuObj.getJSONObject( s ).getInt("sound");
    lastPresented = millis() + 1500;
    sounds[i].play();
    sounds[i].rewind();
  }
}

void readIt() {
  String txt = "";

  for ( int i=0; i<=currentLine; i++ ) {
    txt += textlines[i] + " ";
  }
  pauseFor( 100*txt.length(), false);
  lastPresented = millis();
  lastPresented += 300*txt.length() + 5000; 

  if ( useGoogle ) {
    readByGoogle(txt);
  } else if ( useBrowser ) {
    readByBrowser(txt);
  } else {
    readByEspeak(txt);
  }
}

// read text using espeak
void readByEspeak(String txt) {

  try {
    String[] args1 = {
      //"/usr/local/bin/speak", "-ven+f4", "-g 7", txt
      "say", "-v", "vicki", "-r", "200", txt
    };
    Runtime r = Runtime.getRuntime();
    Process p = r.exec(args1);
    delay(500);
  } 
  catch (IOException ex) {
    println(ex.toString());
  }
}

void readByBrowser(String txt) {

  try {
    String[] args1 = {
      "open", "/Applications/Google Chrome.app", 
      "file:///Users/ylh/0/node/blink/speak.html?txt=" +
        txt
    };
    print("use speack syntheses: " + txt + "+++");
    Runtime r = Runtime.getRuntime();
    Process p = r.exec(args1);
  }  
  catch (IOException ex) {
    println(ex.toString());
  }
}

void readByGoogle(String txt) {

  try {
    String[] args1 = {

      "curl", "-A ", "Mozilla", 
      "https://translate.google.com/translate_tts?tl=en&q=" +
        txt
    };
    println(txt);
    Runtime r = Runtime.getRuntime();
    Process p = r.exec(args1);

    //http://www.ask-coder.com/1527922/java-file-redirection-both-ways-within-runtime-exec
    //   Process proc = Runtime.getRuntime().exec("...");
    InputStream standardOutputOfChildProcess = p.getInputStream();
    OutputStream dataToFile = new FileOutputStream("tmp.mp3");

    byte[] buff = new byte[1024];
    for ( int count = -1; (count = standardOutputOfChildProcess.read (buff)) != -1; ) {
      dataToFile.write(buff, 0, count);
    }

    dataToFile.close();

    delay(500);
    println( args1 );
    gMinim = new Minim( this );
    AudioPlayer s = gMinim.loadFile("tmp.mp3");
    s.play();
  } 
  catch (IOException ex) {
    println(ex.toString());
  }
}

void checkPause() {
  if ( pause && pauseFor>0 && (millis() - whenPaused) > pauseFor ) {
    pause();
  }
}

// pauseFor = 0 means forever
void pauseFor(int ms, boolean show) {
  pauseFor = ms;
  if ( !pause ) pause();
  showCountDown = show;
}

void pause() {

  pause = !pause;  
  if (pause) { // newly paused
    whenPaused = millis();
    morseStr = ""; 
    wroteSpace = true;
    firstTimeMorse = millis();
    frameRate(1);
  } else {  // newly unpaused

    if ( showCountDown ) sayWords( "waking_up" );
    showCountDown = false;

    frameRate(FRAME_RATE);
    firstTimeMorse = millis();
    selected = 0; //============== normal mode
    curItem = "menu5";
  }
  lastPresented = millis();
}

void initPhase1() {
  frameRate(FRAME_RATE);

  mode = REGULAR;
  inputType = REGULAR;
  curItem = prevItem = "menu5";

  morseStr = "";
  firstTimeMorse = millis();
  wroteSpace = true;

  lastPresented = millis();
  presented = false;
  TRANSIT = false;

  if ( pause ) pause();
}

/*

 http://espeak.sourceforge.net/commands.html
 
 YLH: speak "could you please get me some coffee?" -ven+f1 -g 7 -s 170 -p 55
 
 2.2.1 Examples
 
 To use at the command line, type:
 espeak "This is a test"
 or
 espeak -f <text file>
 Or just type
 espeak
 followed by text on subsequent lines. Each line is spoken when RETURN is pressed.
 
 Use espeak -x to see the corresponding phoneme codes.
 
 
 
 2.2.2 The Command Line Options
 
 espeak [options] ["text words"]
 Text input can be taken either from a file, from a string in the command, or from stdin.
 -f <text file>
 Speaks a text file.
 --stdin
 Takes the text input from stdin.
 If neither -f nor --stdin is given, then the text input is taken from "text words" (a text string within double quotes). 
 If that is not present then text is taken from stdin, but each line is treated as a separate sentence.
 -a <integer>
 Sets amplitude (volume) in a range of 0 to 200. The default is 100.
 -p <integer>
 Adjusts the pitch in a range of 0 to 99. The default is 50.
 -s <integer>
 Sets the speed in words-per-minute (approximate values for the default English voice, others may differ slightly). The default value is 175. I generally use a faster speed of 260. The lower limit is 80. There is no upper limit, but about 500 is probably a practical maximum.
 -b <integer>
 Input text character format.
 1   UTF-8. This is the default.
 
 2   The 8-bit character set which corresponds to the language (eg. Latin-2 for Polish).
 
 4   16 bit Unicode.
 
 Without this option, eSpeak assumes text is UTF-8, but will automatically switch to the 8-bit character set if it finds an illegal UTF-8 sequence.
 
 -g <integer>
 Word gap. This option inserts a pause between words. The value is the length of the pause, in units of 10 mS (at the default speed of 170 wpm).
 -h or --help
 The first line of output gives the eSpeak version number.
 -k <integer>
 Indicate words which begin with capital letters.
 1   eSpeak uses a click sound to indicate when a word starts with a capital letter, or double click if word is all capitals.
 
 2   eSpeak speaks the word "capital" before a word which begins with a capital letter.
 
 Other values:   eSpeak increases the pitch for words which begin with a capital letter. The greater the value, the greater the increase in pitch. Try -k20.
 
 -l <integer>
 Line-break length, default value 0. If set, then lines which are shorter than this are treated as separate clauses and spoken separately with a break between them. This can be useful for some text files, but bad for others.
 -m
 Indicates that the text contains SSML (Speech Synthesis Markup Language) tags or other XML tags. Those SSML tags which are supported are interpreted. Other tags, including HTML, are ignored, except that some HTML tags such as <hr> <h2> and <li> ensure a break in the speech.
 -q
 Quiet. No sound is generated. This may be useful with options such as -x and --pho.
 -v <voice filename>[+<variant>]
 Sets a Voice for the speech, usually to select a language. eg:
 espeak -vaf
 To use the Afrikaans voice. A modifier after the voice name can be used to vary the tone of the voice, eg:
 espeak -vaf+3
 The variants are +m1 +m2 +m3 +m4 +m5 +m6 +m7 for male voices and +f1 +f2 +f3 +f4 which simulate female voices by using higher pitches. Other variants include +croak and +whisper.
 <voice filename> is a file within the espeak-data/voices directory.
 <variant> is a file within the espeak-data/voices/!v directory.
 
 Voice files can specify a language, alternative pronunciations or phoneme sets, different pitches, tonal qualities, and prosody for the voice. See the voices.html file.
 
 Voice names which start with mb- are for use with Mbrola diphone voices, see mbrola.html
 
 Some languages may need additional dictionary data, see languages.html
 
 -w <wave file>
 Writes the speech output to a file in WAV format, rather than speaking it.
 -x
 The phoneme mnemonics, into which the input text is translated, are written to stdout. If a phoneme name contains more than one letter (eg. [tS]), the --sep or --tie option can be used to distinguish this from separate phonemes.
 -X
 As -x, but in addition, details are shown of the pronunciation rule and dictionary list lookup. This can be useful to see why a certain pronunciation is being produced. Each matching pronunciation rule is listed, together with its score, the highest scoring rule being used in the translation. "Found:" indicates the word was found in the dictionary lookup list, and "Flags:" means the word was found with only properties and not a pronunciation. You can see when a word has been retranslated after removing a prefix or suffix.
 -z
 The option removes the end-of-sentence pause which normally occurs at the end of the text.
 --stdout
 Writes the speech output to stdout as it is produced, rather than speaking it. The data starts with a WAV file header which indicates the sample rate and format of the data. The length field is set to zero because the length of the data is unknown when the header is produced.
 --compile [=<voice name>]
 Compile the pronunciation rule and dictionary lookup data from their source files in the current directory. The Voice determines which language's files are compiled. For example, if it's an English voice, then en_rules, en_list, and en_extra (if present), are compiled to replace en_dict in the speak-data directory. If no Voice is specified then the default Voice is used.
 --compile-debug [=<voice name>]
 The same as --compile, but source line numbers from the *_rules file are included. These are included in the rules trace when the -X option is used.
 --ipa
 Writes phonemes to stdout, using the International Phonetic Alphabet (IPA).
 If a phoneme name contains more than one letter (eg. [tS]), the --sep or --tie option can be used to distinguish this from separate phonemes.
 --path [="<directory path>"]
 Specifies the directory which contains the espeak-data directory.
 --pho
 When used with an mbrola voice (eg. -v mb-en1), it writes mbrola phoneme data (.pho file format) to stdout. This includes the mbrola phoneme names with duration and pitch information, in a form which is suitable as input to this mbrola voice. The --phonout option can be used to write this data to a file.
 --phonout [="<filename>"]
 If specified, the output from -x, -X, --ipa, and --pho options is written to this file, rather than to stdout.
 --punct [="<characters>"]
 Speaks the names of punctuation characters when they are encountered in the text. If <characters> are given, then only those listed punctuation characters are spoken, eg. --punct=".,;?"
 --sep [=<character>]
 The character is used to separate individual phonemes in the output which is produced by the -x or --ipa options. The default is a space character. The character z means use a ZWNJ character (U+200c).
 --split [=<minutes>]
 Used with -w, it starts a new WAV file every <minutes> minutes, at the next sentence boundary.
 --tie [=<character>]
 The character is used within multi-letter phonemes in the output which is produced by the -x or --ipa options. The default is the tie character  ͡  U+361. The character z means use a ZWJ character (U+200d).
 --voices [=<language code>]
 Lists the available voices.
 If =<language code> is present then only those voices which are suitable for that language are listed.
 --voices=mbrola lists the voices which use mbrola diphone voices. These are not included in the default --voices list
 --voices=variant lists the available voice variants (voice modifiers).
 
 
 2.2.3 The Input Text
 
 HTML Input
 If the -m option is used to indicate marked-up text, then HTML can be spoken directly.
 Phoneme Input
 As well as plain text, phoneme mnemonics can be used in the text input to espeak. They are enclosed within double square brackets. Spaces are used to separate words and all stressed syllables must be marked explicitly.
 eg:   espeak -v en "[[D,Is Iz sVm f@n'EtIk t'Ekst 'InpUt]]"
 
 This command will speak: "This is some phonetic text input".
 
 */

void ListCameras() { 
  String[] cameras = Capture.list();

  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      print(i); 
      print(": ");
      println(cameras[i]);
    }
  }
}
void debugROI(String s) {
  if ( debug) {
    println( s + " ROI:   " + ROI.x + " " + ROI.y + " " + ROI.width+ " " + ROI.height );
    println( s + " found: " + foundROI.x + " " + foundROI.y + " " + foundROI.width+ " " +foundROI.height );
  }
}

PImage trans2( PImage img ) {
  OpenCV newopencv;

  newopencv = new OpenCV(this, img, useColor); // don't use color
  newopencv.blur(1);
  return newopencv.getSnapshot();
}

// process image i
// sets two globals imL[i] and matL[i]
PImage process(int i, PImage inputImg) {
  PImage retImg;
  OpenCV ocv;
  //retImg = get( i*wd, 0, wd, ht);
  ocv = new OpenCV( this, inputImg, false );

  ocv.equalizeHistogram();

  ocv.contrast(1.3);
  //ocv.invert();

  //ocv.threshold(128);
  //ocv.dilate();
  //ocv.erode();
  // ocv.findCannyEdges(20,75);

  //ocv.findSobelEdges(0,1);
  //ocv.invert();
  // ocv.blur(1);

  if ( false ) { // testing old code - don't preprocess if using this
    Mat Mroi;
    ocv.setROI(0, 0, inputImg.width, inputImg.height);
    Mroi = ocv.getROI().clone();

    Imgproc.morphologyEx(Mroi, Mroi, Imgproc.MORPH_GRADIENT, new Mat());

    imL[i] = ocv.getSnapshot(); // just to initialize
    ocv.toPImage( Mroi, imL[i] );
    matL[i] = Mroi;
    return imL[i];
  }

  imL[i] = ocv.getSnapshot();

  ocv.setROI(0, 0, imL[i].width, imL[i].height);
  matL[i]= ocv.getROI().clone(); 
  ocv.releaseROI();

  return imL[i];
}

