//*************
//Coder: Courtney Brown
//Mar. 2024
//Shows how to use a dove syrinx via mouse and envelope control
//Shows how to record to file
//*************

DoveSyrinx syrinx => dac; 
syrinx.init();

///* Uncomment to save results to file
//dac => WvOut2 writer => blackhole; //record to file
//writer.wavFilename("hadrosaurSounds.wav"); //set file name
//null @=> writer; //automatically close file on remove-shred -- is it temporary??

//note-- use WvIn to play a file --> https://chuck.stanford.edu/doc/program/ugen_full.html#WvIn

//uncomment to use mouse to control -- this blocks the rest of the file from running
//syrinx.runWithMouse();

//* uncomment to create a "note" onset of a coo sound.
/*

MultiPointEnvelope air => blackhole;
MultiPointEnvelope muscle => blackhole; 

0.0 => air.startValue;
air.add(0.1, 0.5::second);
air.add(0.8, 0.5::second);
air.add(1, 1::second);
air.add(0.3, 3::second); 
air.add(0.0, 3::second); 
0 => air.loop; //don't loop


0.0 => muscle.startValue;
muscle.add(0.5, 0.5::second);
muscle.add(0.4, 0.05::second);
muscle.add(0.5, 0.5::second);
muscle.add(0.5, 0.5::second);
muscle.add(0.3, 1::second); 
muscle.add(0.0, 0.5::second); 
1 => muscle.loop; //loop

now + 20::second => time later;
while ( later > now )
{
    syrinx.updateInputPressure(air.value()) ;
    syrinx.updateInputMusclePressure(muscle.value()) ;
    air.update(); 
    muscle.update(); 
    1::ms => now;
}
*/

