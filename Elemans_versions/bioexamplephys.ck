
Noise n => ADSR plk => DelayA strng => OneZero lp => dac; 
lp => strng; 

3.0 => float sust; // in seconds


347.4 => float c; // in m/s
//c/(2*(L/100.0)) => float LFreq; // -- the resonant freq. of the tube (?? need to look at this)

float LFreq; 
float period; 
for( 0=>int i; i<20; i++ )
{
    playNotes(); 
}

fun void sustain(float aT60)  {
    aT60 => sust;
    Math.exp(-6.91/sust/LFreq) => lp.gain;
} 

5::second => now;

fun void playNotes()
{
    Noise n => ADSR plk => DelayA strng => OneZero lp => dac; 
    lp => strng;    
        
    Math.random2(150, 1600) => LFreq;
    (( second / samp) /LFreq) - 1 => period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
    period::samp => strng.delay;
    
    (ms,10*ms,0.0,ms) => plk.set; // set noise envelope
    1.0 => n.gain;
    1 => plk.keyOn;   
    
    sustain(2); 
    0.5::second => now; 
}
