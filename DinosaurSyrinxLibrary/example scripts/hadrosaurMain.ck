//*************
//Coder: Courtney Brown
//Mar. 2024
//Shows how to use a hadrosaur syrinx via mouse and envelope control
//Note: This syrinx is the Fletcher/Smyth model based on a raven
//However, it has only 1 syrinx membrane, rather than 2 like a raven to save CPU resources
//Shows how to record to file
//*************
HadrosaurSyrinx syrinx => dac; 
syrinx.init();
5 => syrinx.limiter.gain; //increase volume -- change value if you like.

/* Uncomment to save results to file
dac => WvOut2 writer => blackhole; //record to file
writer.wavFilename("hadrosaurSounds.wav"); //set file name
null @=> writer; //automatically close file on remove-shred -- is it temporary??
*/

/*
//note-- use WvIn to play a file --> https://chuck.stanford.edu/doc/program/ugen_full.html#WvIn
WvIn audioFile => dac; 
"pathToSoundFile" => audioFile.path;
*/

//uncomment to use mouse to control -- this blocks the rest of the file from running
//syrinx.runWithMouse();

//see DoveMain.ck for instrume
// uncomment below to create a "note" onset of a coo sound.

//this is a way to play without using the mouse and doing it in real time.
//You use the envelopes to control the air pressure and muscle parameters across a length of time

//create envelope with different values and length of time to ramp up and down to the values for air pressure
MultiPointEnvelope air => blackhole; //put values into blackhole so they will run when we chuck time, but it doesn't have an audio output
0.0 => air.startValue;
air.add(0.1, 0.2::second);
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


