DoveSyrinx syrinx => dac; 
syrinx.init();
//syrinx.runWithMouse();

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
muscle.add(0.0, 5::second); 
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
