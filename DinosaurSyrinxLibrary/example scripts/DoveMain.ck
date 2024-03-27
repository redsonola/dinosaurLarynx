//*************
//Coder: Courtney Brown
//Mar. 2024
//Shows how to use a dove syrinx via mouse and envelope control
//Shows how to record to file
//This uses the Dove syrinx model developed by Zaccharell, Elemans, et. al. -- you may create Corythosaurus sound by reinitializing parameters
//Parameters based on: Corythosaurus skeletal & skull measurements plus observations/research on how vocal box parameters (size, stiffness, elasticity, other material properties) change with size in birds, alligators, and humans. See references in the library ck files.
//Mouse x - air pressure, increases to the right
//Mouse y - muscle tension, increases as you move your move down to the screen (both the TL muscle and the transmural tension -- transmural tension is inverse-ish to the TL pressure following Zaccarelli's analysis of the dove coo for both dove and dinosaur)
//*************

DoveSyrinx syrinx => dac; 
syrinx.init();
//0.5 => syrinx.limiter.gain //uncomment to decrease volume - change value to increase

//syrinx.makeCorythosaurus(); //uncomment to initialize with Corythosaurus parameters to get a dinosaur sound from this syrinx membrane

///* Uncomment to save results to file -- COMMENT when playing results of same file.
//dac => WvOut2 writer => blackhole; //record to file
//writer.wavFilename("doveSounds.wav"); //set file name
//null @=> writer; //automatically close file on remove-shred -- is it temporary??


//note-- use WvIn to play a file --> https://chuck.stanford.edu/doc/program/ugen_full.html#WvIn
/*
WvIn audioFile => dac; 
//"pathToSoundFile" => audioFile.path; --> this is how to play a saved file
"doveSounds.wav" => audioFile.path; //for example
*/

//uncomment to use mouse to control -- note that this blocks the rest of the file from running
//syrinx.runWithMouse();


//*******************************
// uncomment below to create a "note" onset of a coo sound.
//*******************************
//this is a way to play without using the mouse and doing it in real time.
//You use the envelopes to control the air pressure and muscle parameters across a length of time
//create envelope with different values and length of time to ramp up and down to the values for air pressure
//MultiPointEnvelope::add( valueToRampTo, howLongInSecondsToRampToValue )
/*
MultiPointEnvelope air => blackhole; //put values into blackhole so they will run when we chuck time, but it doesn't have an audio output
0.0 => air.startValue;
air.add(0.1, 0.5::second);
air.add(0.8, 0.5::second);
air.add(1, 1::second);
air.add(0.3, 3::second); 
air.add(0.0, 3::second); 
0 => air.loop; //don't loop

//create an envelope with different values and length of time to ramp up and down to the values for muscle pressure/tension
MultiPointEnvelope muscle => blackhole; //put values into blackhole so they will run when we chuck time, but it doesn't have an audio output
0.0 => muscle.startValue;
muscle.add(0.5, 0.5::second);
muscle.add(0.4, 0.05::second);
muscle.add(0.5, 0.5::second);
muscle.add(0.5, 0.5::second);
muscle.add(0.3, 1::second); 
muscle.add(0.0, 0.5::second); 
1 => muscle.loop; //loop -- when reach last added value go back to start, infinitely until muscle.loop is zero

//loop to play everything for 8.5 seconds
now + 8.5::second => time later;
while ( later > now )
{
    syrinx.updateInputPressure(air.value()) ; //update syrinx air pressure with current value of envelope
    syrinx.updateInputMusclePressure(muscle.value()) ;//update syrinx muscle pressure/tension with current value of envelope
    air.update(); 
    muscle.update(); 
    1::ms => now;
}
*/


