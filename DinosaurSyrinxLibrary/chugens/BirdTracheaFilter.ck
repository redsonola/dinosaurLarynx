//BirdTracheaFilter
//The low-pass filter for the tube waveguide synthesis
//Uses Smyth, 2004 Dissertation to implement reasonably accurate sound reflection filter
//this filter is the sound that reflects back to the syrinx folds
//by Courtney Brown, Mar. 2023

public class BirdTracheaFilter extends Chugen
{
    1.0 => float a1;
    1.0 => float b0;
    0.0 => float lastOut; 
    0.0 => float lastV; 
    
    fun float tick(float in)
    {
        b0*in => float vin;
        vin + lastV - a1*lastOut => float out;
        out => lastOut; 
        vin => lastV; 
        return out; 
    }     
}