//-- http://musicweb.ucsd.edu/~trsmyth/pubs/asa_02.pdf - bird realization
//-- https://www.phys.unsw.edu.au/music/people/publications/Fletcher1988.pdf

// density of s. membrane from: https://www.nature.com/articles/s41598-017-11258-1 (using Smyth's estimation)
// from here: Riede, T., York, A., Furst, S., Muller, R. & Seelecke, S. Elasticity and stress relaxation of a very small vocal fold. J. Biomech. 44, 1936?1940 (2011).

//try this later--
//https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2607454/
//https://findresearcher.sdu.dk/ws/portalfiles/portal/50551636/2006_Zaccarelli_etal_ActaAcustica.pdf
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


//use this reference for signal chain:
//https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=4e817cc2bb7534f4ae506a38900430a7e5644212

//physically-based modeling reference -- see boundary conditions of a closed tube (closed mouth, etc.), p. 16
//http://users.spa.aalto.fi/vpv/publications/vesan_vaitos/ch2.pdf

//Syrinx Membrane
class SyrinxMembrane extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    
    //1.204 => float p; //air density (value used for 68F & atmospheric pressure 101.325 kPa (abs), 1.204 kg/m3
    //0.00118 => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    //1.18 => float p; //over m, air density from Smyt4 diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    //1.18 * Math.pow(10, -3) => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    0.001225  => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    
    //347.4 => float c; //speed of sound (m/s) for now
    34740 => float c; //m //speed of sound from Smyth, 34740 cm/s, so 347.4 m/s,
    
    //pG -  3.0591486389338 --//
    0.0 => float pG; //pressure from the air sac ==> change to create sound, 0.3 or 300 used in Flectcher 1988, possibly 3 in cm units.
    //3.0591486389338 => float pG; //pressure from the air sac ==> change to create sound, 0.3 or 300 used in Flectcher 1988, possibly 3 in cm units.


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
    
    //coefficsents for d2x updates
    2.0 => float q1; 
    //w[1]/(q1*2.0) => float k; //damping coeff. -- k = w1/2*Q1
    300 => float k; //damping coeff. -- k = w1/2*Q1

    15 => float E; //a number of order 10 to 100 to represent stickiness
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
    [0.3, 0.5] @=> float A3[]; // constant in the mass equation -- changed bc there was an NAN after membrane density was put into 
    //the correct units from kg/m^3 to g/cm^3
    
    //***** end biological parameters
    
    //tension
    217.6247770440203 => float initT; //this is the tension to produce 150Hz, the example w in the research articles
    initT => float curT; //tension to produce the default, in N/cm^3
    0.0 => float goalT;//the tension to increase or decrease to    
    0.0 => float dT; //change in tension per sample  
    10.0 => float modT; //how fast tension can change
    
    //changing pG
    0.0 => float goalPG;//the tension to increase or decrease to    
    0.0 => float dPG; //change in tension per sample 
    100.0 => float modPG; //a modifier for how quickly dx gets added
    
        
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
         else 0.5*a*h*(p0 + p1) => F; //not sure, but divided by 2 produced the results
         
         //testing
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
            p/(8.0*a*a*totalX*totalX) => float C; //from Fletcher 
            ( 2.0 *Math.sqrt( a*totalX ) )/p => float D; //actually inverse
  
            //from Fletcher and Smyth -- mas o menos
            timeStep*( dU + ( D * ( p0-p1-( C*U*U ) ) ) ) => dU; //0 < x <= a
           
           
            //Smyth at she beginning of Ch. 5??? but does not correspond to fletcher quite.
            //a*totalX => float At;
            //( (2*Math.sqrt(At) )/p)*(p0 - p1) => dU; 
            //dU - ( (U*U) / ( 4*Math.pow(At, 3.0/2.0) ) )  => dU;
            
             //integrate
             //(timeStep)*(dUPrev + dU) => dU; 
             dU + U => U; 
        
        }
        else
        { 
            0.0 => dU;   
            0.0 => U;          
        }
        
        //is this a fudge, or is this real?
        if ( U < 0 )
        {
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
            
            (A3[i]*pM*pi*a*h*d)/4 => m[i];
            //0.0045 => m[i];
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
        
        //user changing parameters
        updateTensionAndW(); 
        updatePG();
        
        return p1;
    }
    
    //changes tension thus, frequency
    fun void changeTension(float tens)
    {
        tens => goalT; 
    }
    
    fun void updateTensionAndW()
    {
        goalT - curT => float diff; 
        (dT + diff)*T*modT => dT ; //note: this is probably not a good pace, but we'll see??
        curT + dT => curT; 
        
        Math.sqrt( (5*curT) / (pM*a*h*d) ) => w[0]; //Smyth diss.
        w[0]*1.6 => w[1]; //Fletcher1988         
    }
    
    //changes tension thus, frequency
    fun void changePG(float tens)
    {
        tens => goalPG; 
    }
    
    fun void updatePG()
    {
        goalPG - pG => float diff; 
        (dPG + diff)*T*modPG => dPG ; 
        pG + dPG => pG;      
    }

}


class WallLossAttenuation extends Chugen
{
    7.0 => float L; //in cm 
    34740 => float c; // in m/s
    c/(2*L) => float freq;
    wFromFreq(freq) => float w;   
    //150.0*2.0*pi => float w;  
    
    0.35 => float a; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
                     //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    calcPropogationAttenuationCoeff() => float propogationAttenuationCoeff; //theta in Fletcher1988 p466
    calcWallLossCoeff() => float wallLossCoeff; //beta in Fletcher
    0.0 => float out;           
                 
    
    fun float calcConstants()
    {
        wFromFreq(c/(2*L)) => w;
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

//this needs to be checked again
//the h(z) to this is a bit unclear for me
//need to test freq response
class HPFilter extends Chugen
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


//waveguides/tubes altered to model clarinet for an intermediate testable outcome before bronchus, trachea, junction are modeled
//used https://quod.lib.umich.edu/cgi/p/pod/dod-idx/efficient-simulation-of-the-reed-bore-and-bow-string.pdf?c=icmc;idno=bbp2372.1986.054;format=pdf
//& Cook's Real Sound Synthesis as a guide

//WallLossAttenuation wa;

//set globals
0.35 => float a;
7.0 => float L;
0.35 => float h;


//BiQuad loop;
BirdTracheaFilter loop; 
BirdTracheaFilter lp;  

// ********* not a flute paper

//from membrane to trachea and part way back
SyrinxMembrane mem => DelayA delay => lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning

//the feedback from trachea reflection
Gain p1; 
wa => p1; 
mem => p1; 
//p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
p1 => delay;   

//output from trachea
delay => Gain audioOut; 
delay2 => audioOut; 
audioOut => BiQuad hpOut => Dyno limiter =>  dac; 
limiter.limit();

//init the global variables, sigh. chuck.
initGlobals(); 

duck(); 

//**********/

//start event main loop
mouseEventLoopControllingAirPressure();


// ***** Methods *******// 

 function void setParamsForReflectionFilter()
 {
     0.35 => float a; //radius of opening; from Smyth diss
     0.5 => float ka; //from Smyth
     ka*(mem.c/a)*mem.T => float wT; 
     
     //1.8775468475739816 => wT; //try this from example, Ok, No.
     
     <<<wT>>>;
     //magnitude of -1/(1 + 2s) part of oT from Smyth, eq. 4.44
     ka => float s; //this is kaj, so just the coefficient to sqrt(-1)
     #(1, 0) => complex numerator;
     #(1, 2*s) => complex denominator;
     numerator / denominator => complex complexcHr_s;
     Math.sqrt( complexcHr_s.re*complexcHr_s.re + complexcHr_s.im*complexcHr_s.im )  => float oT; //magnitude of Hr(s)
     <<<oT>>>;
     
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
     b0 => hpOut.b0; 

     
     //<<< "wT: " + wT + " oT: " + oT + " a1: "+ a1 + " b0: " + b0 >>>;
 }
 
 function float logScale(float in, float min, float max)
 {
     Math.log( max / min ) / (max - min)  => float b;
     max / Math.exp(b*max) => float a;
     return a * Math.exp ( b*in );
 }
 
 //mouse event loop controlling air pressure
 function void mouseEventLoopControllingAirPressure()
 {
     // HID input and a HID message
     Hid hi;
     HidMsg msg;
     
     // which mouse
     0 => int device;
     // get from command line
     if( me.args() ) me.arg(0) => Std.atoi => device;
     
     // open mouse 0, exit on fail
     if( !hi.openMouse( device ) ) me.exit();
     <<< "mouse '" + hi.name() + "' ready", "" >>>;
     0.0 => float max;
     
     0 => int whichBird; 
     
     // infinite event loop
     while( true )
     {
         // wait on HidIn as event
         hi => now;
         
         // messages received
         while( hi.recv( msg ) )
         {
             // mouse motion
             if( msg.isMouseMotion() )
             {
                 // get the normalized X-Y screen cursor pofaition
                // <<< "mouse normalized position --",
                // "x:", msg.scaledCursorX, "y:", msg.scaledCursorY >>>;
                 Math.sqrt(msg.deltaY*msg.deltaY + msg.deltaX*msg.deltaX) => float val;
               // Math.max(max, val) => max; 
                val / 42 => float totVal; 

                
                60 => float maxPG;
                //msg.scaledCursorY * maxPG => mem.pG;
               // <<< "totVal b4 scale:", totVal >>>;

                totVal * maxPG => float pG; 
                logScale(totVal, 0.0000001, maxPG ) => totVal; 

                mem.changePG(pG); 
 
                
                //<<< "max delta:", max >>>;
                <<< "pG:", mem.pG >>>;
               // <<< "totVal:", totVal >>>;
                
                 logScale( msg.scaledCursorX, 0.0000001, 1.0 ) => float scaledX; 

                
                //we'll say default tension until 3pg
                if(pG < 3.059)
                {  
                    mem.changeTension(mem.initT); 
                }
                else
                {
                    if(whichBird == 0)
                    {  //  Duck-like settings
                        
                        //correlate pG with tension
                        mem.initT => float t;
                        900.0-mem.initT => float scale;
                        msg.scaledCursorY-(3.059/maxPG) => float mult; 
                        
                        //add up to 200 n/cm3 according to x
                        scaledX * 1000.0 => float Tadd;
                        
                        t + mult*scale + Tadd => t; 
                        
                        
                        mem.changeTension(t); 
                        <<< "tension:", t >>>;
                }
                else
                {
                    
                    //correlate pG with tension
                    mem.initT => float t;
                    1500.0-mem.initT => float scale;
                    msg.scaledCursorY-(3.059/maxPG) => float mult; 
                    
                    //add up to 200 n/cm3 according to x
                     scaledX * 3000.0 => float Tadd;

                     //Tadd => t;
                    t + mult*scale + Tadd => t; 
                     //t + Tadd => t; 

                    mem.changeTension(t); 
                   // <<< "tension:", t >>>;
                    hpOut.last() => float trachP1; 
                    Math.max(trachP1, max) => max;
                    //<<< "outAmp: "+ max >>>;
                }
             }
         }
         else if( msg.isButtonDown() )
         {
             //<<< "down:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
             //change which model 
             if( whichBird == 0)
             {
                 whichBird++; 
                 smallBird();
             } 
             else 
             {
                 0 => whichBird;
                 duck(); 
             }
         }    
                 
       }  
     }  
 }
 
 function void smallBird()
 {
     //set for a small bird
     0.19 => a; 
     0.19 => h; 
     2.2 => L;   
     10.0 => hpOut.gain; 
     10 => mem.modT; 
     20.0 => mem.modPG;   
     
     initGlobals(); 
 }
 
 function void duck()
 {
     //set for a larger bird, currently sounds duck-like
     0.35 => a; 
     0.35 => h; 
     7.0 => L;     
     1.0 => hpOut.gain; 
     10.0 => mem.modT; 
     10.0 => mem.modPG; 
    
     initGlobals(); 
 }
 
 function void initGlobals()
 {
     //init the globals
     a => mem.a;
     L => mem.L; 
     h => mem.h;
     a => wa.a;
     L => wa.L; 
     setParamsForReflectionFilter(); 
     wa.calcConstants();  
     
     347.4 => float c; // in m/s
     c/(2*(L/100.0)) => float LFreq; // -- the resonant freq. of the tube (?? need to look at this)
     ( (0.5*second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
     //( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm

     period::samp => delay.delay;
     period::samp => delay2.delay;  
 }

 
 
 /*
Questions/Improvements: 
1. Solidify PA conversion
2. This version clamps the U<0 for stabiliization purposes, this seems to be a superficial fix -- look at.
3. In the reflection filter -- it is not clear how 13.187 kHz is wT given the equations in the Smyth diss.
*/