//*************
//Coder: Courtney Brown
//Mar. 2024
//Shows how to use a hadrosaur syrinx via mouse and envelope control
//Shows how to record to file
//*************
HadrosaurSyrinx syrinx => dac; 
syrinx.init();
20 => syrinx.limiter.gain;

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
syrinx.runWithMouse();

/*
MultiPointEnvelope pressure => blackhole;
MultiPointEnvelope tension => blackhole; 

0.0 => pressure.startValue;
pressure.add(0.1, 0.5::second);
pressure.add(0.8, 0.5::second);
pressure.add(1, 1::second);
pressure.add(0.3, 3::second); 
pressure.add(0.0, 3::second); 
0 => pressure.loop; //don't loop

0.0 => tension.startValue;
tension.add(0.5, 0.5::second);
tension.add(0.4, 0.05::second);
tension.add(0.5, 0.5::second);
tension.add(0.5, 0.5::second);
tension.add(0.3, 1::second); 
tension.add(0.0, 5::second); 
1 => tension.loop; //loop

now + 20::second => time later;
while ( later > now )
{
   syrinx.updateInputPressure(pressure.value()) ;
   syrinx.updateInputTension(tension.value()) ;
   pressure.update(); 
   tension.update(); 
   1::ms => now;
}
*/

