//-- http://musicweb.ucsd.edu/~trsmyth/pubs/asa_02.pdf - bird realization
//-- https://www.phys.unsw.edu.au/music/people/publications/Fletcher1988.pdf

// density of s. membrane from: https://www.nature.com/articles/s41598-017-11258-1
// from here: Riede, T., York, A., Furst, S., Muller, R. & Seelecke, S. Elasticity and stress relaxation of a very small vocal fold. J. Biomech. 44, 1936?1940 (2011).

//try this later--
//https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2607454/
//Biomechanics and control of vocalization in a non-songbird

//survey of early models
//https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=dbca9e2ef474525b4b9417ec92daf0ae88191a97

//2005
//updated songbird model from Fletcher
//https://www.phys.unsw.edu.au/music/people/publications/Fletcher1993.pdf Fletcher1992
//https://www.phys.unsw.edu.au/music/people/publications/Fletcheretal2006.pdf //songbird
//https://www.phys.unsw.edu.au/music/people/publications/Fletcheretal2004.pdf //dove


//https://journals.biologists.com/jeb/article/212/8/1212/19117/Amplitude-and-frequency-modulation-control-of

//-- https://chuck.cs.princeton.edu/extend/#chugens
//-- https://github.com/ccrma/chugins

//another reference to look at: http://legacy.spa.aalto.fi/research/avesound/pubs/akusem04.pdf

//Syrinx Membrane
class SyrinxMembrane extends Chugen
{
    //1.204 => float p; //air density (value used for 68F & atmospheric pressure 101.325 kPa (abs), 1.204 kg/m3
    //0.00118 => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    //1.18 => float p; //over m, air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    1.18 * Math.pow(10, -3) => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    
    //347.4 => float c; //speed of sound (m/s) for now
    34740 => float c; //m //speed of sound from Smyth, 34740 cm/s, so 347.4 m/s,
    
    //pG -  3.0591486389338
    3.091486389338 => float pG; //pressure from the air sac ==> change to create sound, 0.3 or 300 used in Flectcher 1988, possibly 3 in cm units.

    //main values for differential equation, except for x, defined below in it's own block
    0.0 => float p0; //brochial side pressure
    0.0 => float p1; //tracheal side pressure -- **output that is the time-varying signal for audio 
    0.0 => float U; //volume velocity flowing out
   
    //the rate of change that we find at each tick
    0.0 => float dp0; //change in p0, bronchial pressure
    0.0 => float dU; //chage in U, volume velocity
    [0.0, 0.0] @=> float d2x[]; //accel of the membrane per mode
    [0.0, 0.0] @=> float dx[]; //velocity of the membrane per mode
    
    //initialized to prevent x going to 0
    [0.0, 0.0] @=> float x[];  //displacement of the membrane per mode
    0.0 => float totalX; // all the x's added for total displacement
    0.0 => float F; //force driving fundamental mode of membrane
    0.0 => float x0; //equillibrium opening, in cm -- if this is 0.3, close to a -- it does oscillate, but incorrectly
                     //if Force is not added when x is 0, then it will eventually stabilize into a high tone.

    //biological parameters *******
    1.0 => float V; //volume of the bronchius - in cm^3
    [150.0*2.0*pi, 250.0*2.0*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    
    //coefficients for d2x updates
    2.0 => float q1; 
    //w[1]/(q1*2.0) => float k; //damping coeff. -- k = w1/2*Q1
    300 => float k; //damping coeff. -- k = w1/2*Q1

    80.0 => float E; //a number of order 10 to 100 to represent stickiness
    10.0 => float membraneNLCoeff; //membrane non-linear coeff. for masses, etc.
    [1.0, 1.0] @=> float epsilonForceCouple[]; //try -- mode 1 should be dominant.
    
   
    //3.5 => float a; //  1/2 diameter of trachea, in 3.5mm        ??area of membrane at a point
    0.35 => float a; //  1/2 diameter of trachea, in cm        ??area of membrane at a point

   // 3.5 => float h; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm
    0.35 => float h; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm

    //100 => float d; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers
    0.01 => float d; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers, 1mm, decreasing it to 0.01 shows same behavior as 3000pa

    7.0 => float L; //length of the trachea, in 7cm -- HOLD for this one
    
        //c => float pM; //material density of the syrinx membrane, from During, et. al, 2017, itself from mammalian not avian folds, kg/m 
    //0.000102 => float pM; //material density in kg/m^3
    1 => float pM; //values from Smyth 1000.0 kg/m^3, but it should be g/cm3 to match the rest of the units, so 1 g/cm^3
    
    [0.0, 0.0] @=> float m[]; //the masses involved in vibration of each mode 
    0.5 => float A3; // constant in the mass equation -- changed bc there was an NAN after membrane density was put into 
    //the correct units from kg/m^3 to g/cm^3
    
    //***** end biological parameters
    
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
   
     //impedences
    (p*c)/(pi*a*a) => float z0; //impedence of bronchus --small compared to trachea, trying this dummy value until more info 
     z0/6   => float zG; //an arbitrary impedance smaller than z0, Fletcher
     
     0.0 => float inP1; //to output for debugging     
     0.0 => float forceComponent; 
     0.0 => float stiffness; 
     0.0 => float moreDrag; 
     
     0.0 => float testAngle;  
         
    fun void updateForce()
    {
        //set the force -- the limit of the pU^2/7(ax^3)^(1/2) term is 0 when U is 0 -- this is the only way there would 
        //be force with x=0 -- this is not clear in the texts.
        
        //need to consider the force -- at y=0, upstream (p1), F = 2ahp1
        //and downstream -- integrate pressure along y
        // p(y) = p0 + p/2(U/pi*a^2)^2 - (U/2az(y^2)^2)
        // z(y) = x + (a-x)(y/h)^2
        
        //for Fletcher force equation
        1 => float A1; 
        
        //totalX + x0 => float x; 
        totalX => float x; 

        //2*A1*a*h => float memArea;
        //( p0 + p1 )/2 => float pressureDiff;
        //p*U*U => float UFactor;
        //7.0*Math.sqrt(a*x*x*x) => float overArea; 

        //a*h*(p0 + p1) => F[i]; //Smyth
        //2*a*h*(p0 + p1)  => F[i]; //this works to start the model w. a zero x value -- Fletcher
        
        if( x > 0.0 )
        {
           a*h*(p0 + p1) - (2.0*p*U*U*h)/(7.0*Math.pow(a*x, 1.5)) => F; //-- Smyth 
           //memArea* ( ( pressureDiff ) - ( UFactor/overArea  ) ) => F; //fletcher

         }
         else a*h*(p0 + p1) => F; // not sure about this, so -- ok checked this, and am more sure
     }
     
    fun void updateBrochialPressure()
    {        
        (T/2.0) => float timeStep; 

        (p*c*c) / V => float physConstants; 
        (pG - p0) / zG => float preshDiff; 

        timeStep*( dp0 + (physConstants * (preshDiff-U) )) => dp0; 
        
        p0 + dp0 => p0; //this is correct, below is incorrect, but keep this way for now to prevent blow-up
    }
    
    fun void updateU()
    {
        //<<< "before U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;
     
        if( totalX > 0.0 )
        {
            dU => float dUPrev; 
        
            (T/2.0) => float timeStep; 
            //p/(8*a*a*totalX*totalX) => float C; //from Fletcher 
            //2*Math.sqrt(a*totalX)/p => float D; //actually inverse
  
            //from Fletcher and Smyth -- mas o menos
           //timeStep*(dU + D*(p0-p1-(C*U*U))) => dU; //0 < x <= a
           
           
            //Smyth at she beginning of Ch. 5??? but does not correspond to fletcher quite.
            a*totalX => float At;
            ( (2*Math.sqrt(At) )/p)*(p0 - p1) => dU; 
            dU - ( (U*U) / ( 4*Math.pow(At, 3.0/2.0) ) )  => dU;
            
             //integrate
             (timeStep)*(dUPrev + dU) => dU; 
             dU + U => U; 
        
        }
        else
        { 
            0.0 => dU;   
            0.0 => U;          
        }


        //<<< "after U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;

 
    }
    
    fun void updateMass()
    {


        for( 0 => int i; i < x.cap() ; i++ )
        {
            (x[i]-x0)/h => float square; 
            square*square => float squared;
            
            (A3*pM*pi*a*h*d)/4 => m[i];
            //0.045 => m[i];
            m[i] * ( 1 + ( membraneNLCoeff*squared) ) => m[i]; 
        }
        
    }
    
    fun void updateX()
    {
        0.0 => totalX;
        (T/2.0) => float timeStep; 

        for( 0 => int i; i < x.cap() ; i++ )
        {
            
            k => float modifiedK;
            if( x[i] <= 0 )
            {
                k*E => modifiedK;
            }

            //update d2x
            //epsilon is taken as unity
           ( F*epsilonForceCouple[i] ) / m[i] =>  forceComponent; 
           ( - 2.0*modifiedK*dx[i]  ) =>  stiffness; 
           (- w[i]*w[i]*(x[i]-x0) ) =>  moreDrag; 
           
            forceComponent + stiffness + moreDrag => float nextDx2;
            timeStep*(d2x[i] + nextDx2) => d2x[i];
                        
            //update dx, integrate
            dx[i] => float dxPrev;
            dx[i] + d2x[i] => dx[i];
            
            //update x, integrate again
            x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 
            x[i] + totalX => totalX; 

        }
        totalX + x0 => totalX;           
        
        //(Math.cos(testAngle++*2*pi*333.33/SRATE) + 1.0)*2.0 => totalX;
        //totalX * 0.1 => totalX; 
    }
    
    fun void updateP1()
    {
        U*z0 => p1;
        //Math.cos(testAngle) * 900.0 => p1; 
        //testAngle + T*100.0 => testAngle; 
        
        //300.0 => p1;
        
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


class WallLossAttenuation extends Chugen
{
    7.0 => float L; //in cm 
    34740 => float c; // in m/s
    c/(4*L) => float freq;
    wFromFreq(freq) => float w;   
    //150.0*2.0*pi => float w;  
    
    0.35 => float a; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
                     //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    calcPropogationAttenuationCoeff() => float propogationAttenuationCoeff; //theta in Fletcher1988 p466
    calcWallLossCoeff() => float wallLossCoeff; //beta in Fletcher
    0.0 => float out;           
                 
    
    fun float calcConstants()
    {
        wFromFreq(freq) => w;
        calcPropogationAttenuationCoeff() => propogationAttenuationCoeff;
        calcWallLossCoeff() => wallLossCoeff;
        
    } 
    
    fun float calcWallLossCoeff()
    {
        return 1.0 - (1.2*propogationAttenuationCoeff*L);
        //return 1.0 - (2.0*propogationAttenuationCoeff*L);
    }
    
    fun float calcPropogationAttenuationCoeff()
    {
        return (2*Math.pow(10, -5)*Math.sqrt(w)) / a; 
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

//this is redundant but I definitely know what is happening here and will stop any crazy magical thinking debug loops on this topic cold.
class Flip extends Chugen
{
    
    //the pressure up, pressure down difference
    fun float tick(float in)
    {
       return in*-1.0;   
    }  
}


//Scattering junction for where bronchial tubes meet
//pnOut = pJ - pnOut
//Zn - impedences 
//pJ = 2*sumOf(pnOuts*1/Zns)/sumOf(Zns)
class ScatteringJunction extends Chubgraph
{ 
    
    inlet => Gain bronchus1Z => Gain add; 
    inlet => Gain bronchus2Z =>  add;; 
    inlet => Gain tracheaZ =>   add; 
    
    0.00118 => float p; 
    0.35 => float a; 
    34740 => float c; 
    (p*c)/(pi*a*a) => float z0;
    
    //assume they have the same tube radius for now - I guess they prob. don't
    1.0/z0 => bronchus1Z.gain;
    1.0/z0 => bronchus2Z.gain;
    1.0/z0 => tracheaZ.gain;
    2 => add.gain; 
    
    (1.0/z0 + 1.0/z0 + 1.0/z0) => float zSum; 
    
    add => Gain pJ; 
    1.0/zSum => pJ.gain; 
    
    pJ => Gain bronchus1Zout;
    bronchus1Z => bronchus1Zout => outlet;
    bronchus1Zout.op(2); 
    
    pJ => Gain bronchus2Zout;
    bronchus1Z => bronchus2Zout => outlet;
    bronchus2Zout.op(2);
    
    pJ => Gain tracheaZout;
    tracheaZout.op(2); 
    tracheaZ => tracheaZout  => outlet;
}

//okay, this is just to test -- sanity debug check -- make sure -- obviously I can't keep this as a chugen, but probably
//in end result will not be using chugens at all.
class BirdTracheaFilter extends Chugen
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


//waveguides/tubes altered to model clarinet for an intermediate testable outcome before bronchus, trachea, junction are modeled
//used https://quod.lib.umich.edu/cgi/p/pod/dod-idx/efficient-simulation-of-the-reed-bore-and-bow-string.pdf?c=icmc;idno=bbp2372.1986.054;format=pdf
//& Cook's Real Sound Synthesis as a guide

//WallLossAttenuation wa;


//BiQuad loop;
BirdTracheaFilter loop; 
BirdTracheaFilter lp; 

//WallLossAttenuation wallLoss; 
//wallLoss. float waCoeff;
//OneZero lp; 
//LPF lp; 


SyrinxMembrane mem => DelayA delay => lp => blackhole; //from membrane to trachea
//loop => BiQuad hpOut => Gain reduce => dac; //from trachea to sound out


lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning
Gain p1; 
wa => p1; 
mem => p1; 
p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
//p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
p1 => delay; 

delay => Gain audioOut; 
delay2 => audioOut; 
audioOut => BiQuad hpOut => dac; 


1.0::samp => oz.delay; 

//-1.0 => flip.gain;

//<<< wa2.wallLossCoeff >>>;


//test w.0 trachea
//SyrinxMembrane mem =>sGain g => blackhole; 
//g => mem; 


(1.0/(993.6520) ) => hpOut.gain; 


//trachea length -- 70mm, from Fletcher
//0.7 => float L; //in m 

0.07 => float L; //in m 
//0.072375 => float L; //TRY
347.4 => float c; // in m/s
c/(4*L) => float LFreq; // -- the resonant freq. of the tube (?? need to look at this)
( (0.5*second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
//( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm

period::samp => delay.delay;
period::samp => delay2.delay;


//approximating from Smyth diss. 
setParamsForReflectionFilter();
       

FileIO fout;


// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/out2.txt", FileIO.WRITE );

// test
if( !fout.good() )
{
    cherr <= "can't open file for writing..." <= IO.newline();
    me.exit();
}


-326.3054 => float hMax; 
50.0 => float hMin; 

0.0 => float mMax; 
1.0 => float mMin; 

15::second => now; 

//<<<wa2.wallLossCoeff>>>;

now => time start;
 while(now - start < 0.1::second)
 {
     
hpOut.last() => float trachP1; 
delay.last() => float returnTrachp1;
wa.last() => float afterWA; 
loop.last() => float afterLP; 
p1.last() => float adderOut; 
delay2.last() => float beforeAdd;  

     
      <<<"adderOut: " +  adderOut + " afterLP: " + afterLP + " afterWA: " + afterWA + " returnTrachp1: " + returnTrachp1 + " trachP1:" + trachP1 + " z0: "+ mem.z0 +" dp0:" + mem.dp0 +" p0:" + mem.p0 +" d2x[0]:" + mem.d2x[0] + " dU: " + mem.dU + "  U: " + mem.U + " p1-in: " +  mem.inP1 + " x: " + mem.totalX  +  " p1-out:" + mem.p1  >>> ;
      mem.p0 + "," + mem.U + "," + mem.totalX + "," + mem.inP1 + "\n"  => string output; 
      
      
   //    <<<"adderOut: " +  adderOut + " afterLP: " + afterLP + " afterWA: " + afterWA + " returnTrachp1: " + returnTrachp1 
   //    + " trachP1:" + trachP1 + " beforeAdd " + beforeAdd + " p1-in: " +  mem.inP1 +" p1-out:" + mem.p1  >>> ;
   //   mem.p0 + "," + mem.U + "," + mem.totalX + "," + mem.inP1  => string output;       


      //<<<"  p0:" + mem.p0+ "  dU: " + mem.dU + "  U: " + mem.U + "  x: " + mem.totalX + " in-p1:" + mem.inP1 + " p1:" + mem.p1 + " trachP1: " + trachP1 + " returnTrachp1: " + returnTrachp1  >>> ;

   // <<< "#2 ==> F: " + mem.F + " m[0]: " + mem.m[0] + " x[0]: " + mem.x[0] + " dx[0]: " + mem.dx[0] + " d2x[0]: " + mem.d2x[0]  +" x[1]: " + mem.x[1] + " dx[1]" + mem.dx[1] + " d2x[1]: " + mem.d2x[1]  + "  x: " + mem.totalX  >>> ;

    //<<< "forceComponant: " + mem.forceComponent + " stiffness: " + mem.stiffness + " moreDrag: " + mem.moreDrag >>>;

     fout.write( output ); 
     
     Math.max(mMax, mem.totalX) => mMax;
     Math.min(mMin, mem.totalX) => mMin;
     
     Math.max(hMax, trachP1) => hMax;
     Math.min(hMin, trachP1) => hMin;

1::samp => now;   
 }  
 
 
 <<< "mMax: " + mMax>>>;
  <<< "mMin: " + mMin>>>;
  
   <<< "hMax: " + hMax>>>;
  <<< "hMin: " + hMin>>>;

 
 // close the thing
fout.close();

//--2/21 1p fixed reflection filter
 function void setParamsForReflectionFilter()
 {
     0.35 => float a; //radius of opening; from Smyth diss
     0.5 => float ka; //from Smyth
     ka*(mem.c/a)*mem.T => float wT; 
     
     //1.8775468475739816 => wT; //try this from example 
     
     <<<wT>>>;
     0.5 => float s; 
     (s*s)/(1+s*s) => float oT; //Real part of oT from Smyth
     //s/(1+s*s) => float oT; //imaginary part of oT from Smyth
     ( 1 + Math.cos(wT) - 2*oT*oT*Math.cos(wT) ) / ( 1 + Math.cos(wT) - 2*oT*oT ) => float alpha; //to determine a1 
     -alpha + Math.sqrt( alpha*alpha - 1 ) => float a1;
     (1 + a1 ) / 2 => float b0; 
     
     //using a biquad  to implement, eg. https://ccrma.stanford.edu/~jos/fp/BiQuad_Section.html
     //as xfer function matches Smyth 4.47, here, b0 = g, and implemented as suggested in the above link.
     //for the low-pass reflector
     a1 => loop.a1;
     b0 => loop.b0; 
    // b0 => loop.b1;
    // 0 => loop.b2; 
    // 0 => loop.a2; 
     
     //for the highpass output, from Smyth, again
     a1 => hpOut.a1; 
     -1.0-b0 => hpOut.b0; 
     (a1-b0)/(-1.0-b0) => hpOut.b1; 
     0 => hpOut.b2; 
     0 => hpOut.a2; 
     
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