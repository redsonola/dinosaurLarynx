// SIMPLE ENVELOPE FOLLOWER, by P. Cook
//modified by CDB Oct. 2022 to turn into function
//used to translate audio input from microphone into driving other things.
public class EnvelopeFollower
{    function OnePole envelopeFollower()
    {
        // patch
        adc => Gain g => OnePole p => blackhole;
        
        // square the input
        adc => g;
        // multiply
        3 => g.op;
        
        // set pole position
        return p; 
    }
}