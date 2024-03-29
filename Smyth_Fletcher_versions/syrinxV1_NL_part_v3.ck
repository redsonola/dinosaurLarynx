//-- http://musicweb.ucsd.edu/~trsmyth/pubs/asa_02.pdf - bird realization
//-- https://www.phys.unsw.edu.au/music/people/publications/Fletcher1988.pdf

// density of s. membrane from: https://www.nature.com/articles/s41598-017-11258-1
// from here: Riede, T., York, A., Furst, S., Muller, R. & Seelecke, S. Elasticity and stress relaxation of a very small vocal fold. J. Biomech. 44, 1936?1940 (2011).


//https://journals.biologists.com/jeb/article/212/8/1212/19117/Amplitude-and-frequency-modulation-control-of

//-- https://chuck.cs.princeton.edu/extend/#chugens
//-- https://github.com/ccrma/chugins

//Syrinx Membrane
class SyrinxMembrane extends Chugen
{
    //1.204 => float p; //air density (value used for 68F & atmospheric pressure 101.325 kPa (abs), 1.204 kg/m3
    //0.00118 => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    1.18 * Math.pow(10, -3) => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    // 1.18 => float p; //over m, air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters

    
    //1.18 => float p; //air density from Smyth diss., 0.00118cm, 0.0118 mm


    0.0 => float p0; //brochial side pressure
    0.0 => float p1; //tracheal side pressure -- **output that is the time-varying signal for audio 
    //3.3129 => float c; //speed of sound (m/s) for now
    34740 => float c; //m //speed of sound from Smyth, 34740 cm/s, so 347.4 m/s, 

    1.0 => float V; //volume of the bronchius - in cm^3
    300 => float pG; //pressure from the air sac ==> change to create sound, 0.3 or 300 used in Flectcher 1988
    300.0 => float k; //damping coeff. sec^-1, to make it sec /10
    [12.0, 89.0] @=> float E[]; //a number of order 10 to 100 to represent stickiness
    [150.0*2.0*pi, 250.0*2.0*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    
    //3.5 => float a; //  1/2 diameter of trachea, in 3.5mm        ??area of membrane at a point
    0.35 => float a; //  1/2 diameter of trachea, in cm        ??area of membrane at a point

    [0.0, 0.0] @=> float F[]; //force driving fundamental mode of membrane
    //3.5 => float h; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm
    0.35 => float h; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm

    0.0 => float U; //volume velocity flowing out
    10.0 => float membraneNLCoeff; //membrane non-linear coeff. for masses, etc.
    0.04 => float x0; //equillibrium opening
    //100 => float d; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers
    0.1 => float d; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers, 1mm

    70.0 => float L; //length of the trachea, in 0.7cm -- HOLD for this one
    0.0 => float D; //density of the mass
    
    //the rate of change that we find at each tick
    0.0 => float dp0; //change in p0, bronchial pressure
    0.0 => float dU; //chage in U, volume velocity
    [0.0, 0.0] @=> float d2x[]; //accel of the membrane per mode
    [0.0, 0.0] @=> float dx[]; //velocity of the membrane per mode
    
    //initialized to prevent x going to 0
    [0.0, 0.0] @=> float x[];  //displacement of the membrane per mode
    0.0 => float totalX; // all the x's added for total displacement
    
    [0.0, 0.0] @=> float m[]; //the masses involved in vibration of each mode
    0.3 => float A3; // constant in the mass equation
    
    //c => float pM; //material density of the syrinx membrane, from Düring, et. al, 2017, itself from mammalian not avian folds, kg/m 
    //0.000102 => float pM; //material density in kg/m3
    1000.0 => float pM; //values from Smyth 
    
    second/samp => float SRATE;
    1.0/SRATE => float T; //to make concurrent with Smyth paper
   
     (p*c)/(pi*a*a) => float z0; //impedence of bronchus --small compared to trachea, trying this dummy value until more info 
     z0 / 2.0 => float zG; //an arbitrary impedance smaller than z0, Fletcher
     
     0.0 => float inP1; //to output for debugging
     
     //1 => int testAngle;  



    
    fun void updateForce()
    {
        //set the force -- the limit of the pU^2/7(ax^3)^(1/2) term is 0 when U is 0 -- this is the only way there would 
        //be force with x=0 -- this is not clear in the texts.
        
        //a*h*(p0 + p1) => F; //Smyth

        //2*a*h*(p0 + p1)  => F; //this works to start the model w. a zero x value -- Fletcher
        //a*h*(p0 + p1) => F; //Smyth
        1.0 => float A1; 
        
        for( 0 => int i; i < x.cap() ; i++ )
        {
            0.0 => F[i]; 

            if( x[i] > 0.0 )
            {
                a*h*(p0 + p1) - (2.0*p*U*U*h)/(7.0*Math.pow(a*x[i], 1.5)) => F[i]; //-- Smyth 
                //2*a*h*(p0 + p1) - 2*a*h*((p*U*U)/(7.0*Math.sqrt(a*totalX*totalX*totalX))) => F; //fletcher
            }
        }
        
     }
     
    fun void updateBrochialPressure()
    {
        dp0 => float dp0Prev;
        
        (T/2.0) => float timeStep; 
        (p*c*c) / V => float physConstants;
        (pG - p0) / zG => float preshDiff; 

        timeStep*( dp0 + (physConstants * (preshDiff-U) )) => dp0; 
        
        p0 + dp0 => p0; //this is correct, below is incorrect, but keep this way for now to prevent blow-up
        //p0 + (T/2.0)*(dp0Prev + dp0) => p0;
    }
    
    fun void updateU()
    {
        //<<< "before U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;
     
        if(totalX > 0.0)
        {
            dU => float dUPrev; 
        
            (T/2.0) => float timeStep; 
            //p/(8*a*a*totalX*totalX) => float C; //from Fletcher 
            //p/2*Math.sqrt(a*totalX) => float D;
  
            //from Fletcher and Smyth -- mas o menos
            //timeStep*(dU + (1/D)*(p0-p1-(C*U*U))) => dU; //0 < x <= a
           
           
            //Smyth at the beginning of Ch. 5??? but does not correspond to fletcher quite.
            a*totalX => float At;
            ((2*Math.sqrt(At))/p)*(p0 - p1) => dU; 
            dU - ( (U*U) / Math.pow(4*At, 1.5) )  => dU;
        
            //dU + U => U; 
            U + (timeStep)*(dUPrev + dU) => U;
        }
        else 0.0 => U; 
        
        //<<< "after U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;

 
    }
    
    fun void updateMass()
    {


        for( 0 => int i; i < x.cap() ; i++ )
        {
            (x[i]-x0)/h => float square; 
            square*square => float squared;
            
            (A3*pM*pi*a*h*d)/4 => m[i];
            m[i] * ( 1 + ( membraneNLCoeff*squared) ) => m[i]; 
        }
        
    }
    
    fun void updateX()
    {
        0.0 => totalX;
        for( 0 => int i; i < x.cap() ; i++ )
        {
            
            k => float modifiedK;
            //maybe take out for testing
            if( x[i] <= 0 )
            {
                k*E[i] => modifiedK;
            }

            
            //update d2x
            //epsilon is taken as unary
            (T/2.0)*(d2x[i] + F[i]/m[i] - 2.0*modifiedK*dx[i] - w[i]*w[i]*(x[i]-x0)) => d2x[i];
            
            //update dx, integrate
            dx[i] => float dxPrev;
            dx[i] + d2x[i] => dx[i];
            
            //update x, integrate again
            x[i] + (T/2.0)*(dxPrev + dx[i]) => x[i];
            
            x[i] + totalX => totalX; 

        }  
        
        
        //(Math.cos(testAngle++*2*pi*333.33/SRATE) + 1.0)*2.0 => totalX;
        //totalX * 0.1 => totalX; 
    }
    
    fun void updateP1()
    {
        U*z0 + p1 => p1;
    }
    
    
    
    fun float tick(float in)
    {
        in => p1;
        p1 => inP1;
                 
        updateBrochialPressure();
        updateU(); 
        
        //update x & params needed for x
        updateForce(); 
        updateMass();
        updateX();
        
        updateP1(); 
        
        return p1;
    }
}

//Scattering junction for where bronchial tubes meet, can use .chan(n) to access each input
class SyrinxScatteringJunction extends Chugen
{
    
    
    //the two different bronchi as they connect in1 & in2
    fun float tick(float bronchus1, float bronchus2, float trachea)
    {
        
    }  
}



//waveguides/tubes altered to model clarinet for an intermediate testable outcome before bronchus, trachea, junction are modeled
//used https://quod.lib.umich.edu/cgi/p/pod/dod-idx/efficient-simulation-of-the-reed-bore-and-bow-string.pdf?c=icmc;idno=bbp2372.1986.054;format=pdf
//& Cook's Real Sound Synthesis as a guide
SyrinxMembrane mem => DelayA delay => PoleZero loop => blackhole;
loop => Delay delay2 => delay;
loop => Gain p1Add;
delay2 => p1Add; 
p1Add => OnePole lp => mem; 

//second/50 = delay.max;
//500 => float freq; 

//((second / samp) / freq - 1) => float period;
70 => float LFreq; //trachea length -- 70mm, from Fletcher -- need to see if this is calculated from length correctly in Cook & Smyth 
((second / samp) / LFreq - 1) => float period; 
period::samp => delay.delay;
period::samp => delay2.delay;

//approximating from Smyth diss. 
setParamsForReflectionFilter();
       
now => time start;

FileIO fout;


// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/out2.txt", FileIO.WRITE );

// test
if( !fout.good() )
{
    cherr <= "can't open file for writing..." <= IO.newline();
    me.exit();
}


 while(now - start < 1::second)
 {
//       <<< " dp0:" + mem.dp0 +" zG:" + mem.zG + " d2x: " + mem.d2x[0] + "  U: " + mem.U + " F0: " + mem.F[0] +  "  x: " + mem.totalX + "  p0:" + mem.p0 + "  p1:" + mem.p1 + "  input p1: " + mem.inP1 >>> ;
//      mem.p0 + "," + mem.U + "," + mem.totalX + "," + mem.inP1 + "\n" => string output; 

       <<<"  p0:" + mem.p0+ "  dU: " + mem.dU + "  U: " + mem.U + "  x: " + mem.totalX + " p1:" + mem.p1 + "  input p1: " + mem.inP1 >>> ;

   // <<< "F: " + mem.F + "x[0]: " + mem.x[0] + " dx[0]: " + mem.dx[0] + " d2x[0]: " + mem.d2x[0]  +" x[1]: " + mem.x[1] + " dx[1]" + mem.dx[1] + " d2x[1]: " + mem.d2x[1]  + "  x: " + mem.totalX  >>> ;

//      fout.write( output ); 

10::ms => now;   
 } 
 
 // close the thing
fout.close();
 
 function void setParamsForReflectionFilter()
 {
     3.5 => float a; //radius of opening; from Smyth diss
     0.5 => float ka; //from Smyth
     ka*(mem.c/a)*mem.T => float wT; 
     0.5 => float s; 
     (s*s)/(1+s*s) => float oT; //Real part of oT from Smyth
     //s/(1+s*s) => float oT; //imaginary part of oT from Smyth
     ( 1 + Math.cos(wT) - 2*oT*oT*Math.cos(wT) ) / ( 1 + Math.cos(wT) - 2*oT*oT ) => float alpha; //to determine a1 
     -alpha + Math.sqrt( alpha*alpha - 1 ) => float a1;
     (1 + a1 ) / 2 => float b0; 
     
     a1 => loop.a1;
     b0 => loop.b0; 
     0 => loop.b1; 
     
     //<<< "wT: " + wT + " oT: " + oT + " a1: "+ a1 + " b0: " + b0 >>>;

 }
 

 
 /*
 Questions: 
 1. how to add reflection, etc. values to p1? -- it says just to sum the traveling waves --NOTE: working on this see above solution
 2. the U is too small, x is too small, etc. everything except for p0 is too small..
 
 More: 
 which force equation is the best equation?
 why are D & C equations modified in the Symth?
 
 are there measurement unit differences/errors in the constants?
 
 how does it start with all the x values being 0? -- it works if the force is create w.o x, the term with x is just dropped.....s
 
 */