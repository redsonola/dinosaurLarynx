//Coder: Courtney Brown, Mar. 2023
//Based on Smyth high-pass filter in 2004 to mimic the bird beak
//*********************************************************************

//*********************** HIGH PASS FILTER FOR BEAK OUTPUT  
//High pass filter to mimic beak filtering. public class HPFilter extends Chugen
public class HPFilter extends Chugen
{
    1.0 => float a1;
    1.0 => float b0;
    0.0 => float lastOut; 
    0.0 => float lastV; 
    
    fun float tick(float in)
    {
        in - b0*in => float vin;
        vin + (a1-b0)*lastV - a1*lastOut => float out;
        out => lastOut; 
        vin => lastV; 
        return out; 
    }     
}