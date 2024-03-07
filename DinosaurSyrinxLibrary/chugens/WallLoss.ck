//WallLossAttenuation -- implementation of Fletcher's 1988 lumped sum wall loss hack
//models the energy loss from the surface of the tube (eg. trachea, bronchi)
//Coded by Courtney Brown, Mar. 2023

//Using a lumped loss scaler value for wall loss. TODO: implement more elegant filter for this, but so far, it works, so after everything else works.
public class WallLossAttenuation extends Chugen
{
    7.0 => float L; //in cm --divided by 2 since it is taken at the end of each delay, instead of at the end of the waveguide
    34740 => float c; // in m/s
    c/(2*L) => float freq;
    wFromFreq(freq) => float w;   
    //150.0*2.0*pi => float w;  
    
    0.35 => float a; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
    //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    calcPropogationAttenuationCoeff() => float propogationAttenuationCoeff; //theta in Fletcher1988 p466
    calcWallLossCoeff() => float wallLossCoeff; //beta in Fletcher
    0.0 => float out;           
    
    
    fun void calcConstants()
    {
        c/(2*L) => freq;
        wFromFreq(freq) => w;
        calcPropogationAttenuationCoeff() => propogationAttenuationCoeff;
        calcWallLossCoeff() => wallLossCoeff;
        
        /*
        <<< "******* START WALL LOSS ******" >>>;
        <<< "a:"+a >>>;
        <<< "w:"+w >>>;
        <<< "wallLossCoeff:"+wallLossCoeff >>>;
        <<< "L:"+L >>>;
        <<< "******* END WALL LOSS ******" >>>;
        */
        
    } 
    
    fun float calcWallLossCoeff()
    {
        //return 1.0 - (1.2*propogationAttenuationCoeff*L);
        return 1.0 - (2.0*propogationAttenuationCoeff*L);
    }
    
    fun float calcPropogationAttenuationCoeff()
    {
        return (5*Math.pow(10, -5)*Math.sqrt(w)) / a; //changed the constant for more loss, was 2.0
    }
    
    fun float wFromFreq(float frq)
    {
        return frq*Math.PI*2; 
    }
    
    fun void setFreq(float f)
    {
        wFromFreq(f); 
    }
    
    //the two different bronchi as they connect in1 & in2
    fun float tick(float in)
    {
        in*wallLossCoeff => out;
        return out; 
    } 
    
    fun float last()
    {
        return out; 
    } 
}