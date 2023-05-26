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

//Dinosaur Lung, etc. links:
//Schacher, et. al (2011) -- https://anatomypubs.onlinelibrary.wiley.com/doi/pdf/10.1002/ar.21439 -- Evolution of the Dinosauriform Respiratory Apparatus: New Evidence from the Postcranial Axial Skeleton
//O'Connor PM. 2006. Postcranial pneumaticity: an evaluation of softtissue influences on the postcranial skeleton and the reconstruction of pulmonary anatomy in archosaurs. J Morphol 267:1199?1226.  --- https://people.ohio.edu/oconnorp/PDFs/OConnor_2006_Archosaur%20Pneumaticity.pdf
//Brocklehurst, Schacher (2020) -- Respiratory --  https://royalsocietypublishing.org/doi/pdf/10.1098/rstb.2019.0140?download=true
//https://anatomypubs.onlinelibrary.wiley.com/doi/pdf/10.1002/ar.23046 - Breathing Life Into Dinosaurs: Tackling Challenges of Soft-Tissue Restoration and Nasal Airflow in Extinct Species
//https://onlinelibrary.wiley.com/doi/abs/10.1002/jez.548

//Corythosaurus sizes
//https://www.proquest.com/citedreferences/MSTAR_2440425772/4C70A2332F914DFCPQ/1?accountid=6667
//& downloaded --> see

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
    //[150.0*2.0*pi, 250.0*2.0*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    
    //this one worked for a dino-like sound
    [200*2.0*pi*.75, 1.6*200*pi*.75] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    w[0] => float initW;  
   
     //  [500*2.0*pi, 1.6*500*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth


    //coefficients for d2x updates
    2.0 => float q1; 
    w[1]/(q1*2.0) => float k; //damping coeff. -- k = w1/2*Q1
    //300 => float k; //damping coeff. -- k = w1/2*Q1

    15 => float E; //a number of order 10 to 100 to represent stickiness
    10.0 => float membraneNLCoeff; //membrane non-linear coeff. for masses, etc.
    [2.0, 1.0] @=> float epsilonForceCouple[]; //try -- mode 1 should be dominant.
    
   
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
    //217.6247770440203 => float initT; //this is the tension to produce 150Hz, the example w in the research articles
    //Math.sqrt( (5*curT) / (pM*a*h*d) ) => w[0]
    (w[0]*w[0]*pM*a*h*d)/5 => float initT; //this is the tension to produce 150Hz, the example w in the research articles
    initT => float curT; //tension to produce the default, in N/cm^3
    0.0 => float goalT;//the tension to increase or decrease to    
    0.0 => float dT; //change in tension per sample  
    10.0 => float modT; //how fast tension can change
    0.0 => float diff; 
    
    //changing pG
    0.0 => float goalPG;//the tension to increase or decrease to    
    0.0 => float dPG; //change in tension per sample 
    100.0 => float modPG; //a modifier for how quickly dx gets added
    
        
    //impedences
    (p*c)/(pi*a*a) => float z0; //impedence of bronchus --small compared to trachea, trying this dummy value until more info 
    z0/12   => float zG; //an arbitrary impedance smaller than z0, Fletcher
     
     0.0 => float inP1; //to output for debugging     
     0.0 => float forceComponent; 
     0.0 => float stiffness; 
     0.0 => float moreDrag; 
     
     0.0 => float testAngle;  
     
    fun void initZ0()
    {
        (p*c)/(pi*a*a) => z0; 
    }
              
    fun void initTension()
    {
        (initW*initW*pM*a*h*d)/5 => initT;
        initT => goalT; 
    }     
         
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
        goalT - curT => diff; 
        if(diff > 0)
        {            
            //(dT + diff)*T*modT => dT ; 
            //curT + dT => curT; 
        
            Math.sqrt( (5*curT) / (pM*a*h*d) ) => w[0]; //Smyth diss.
            // w[0]*1.6 => w[1]; //Fletcher1988     
            w[0]*1.6 => w[1]; //this is essentially the same thing, but nevertheless, as this is how I discovered frequencies that 
            //better fit the dimensions   
        }    
    }
    
    //changes the air flow
    fun void changePG(float tens)
    {
        tens => goalPG; 
    }
    
    fun void updatePG()
    {
        goalPG - pG => float diff; 
        (dPG + diff)*T*modPG => dPG ; 
        pG + dPG => pG;  
        
        //here I'm trying to mimic the slight variations introduced by my hand when I am controlling 
        //via mouse and it sounds vocal, so that it sounds vocal all the time
        //TODO: take out when doing the breath.
        testAngle+0.01 => testAngle; 
        if(testAngle > Math.pi*2)
        {
            0.0=>testAngle;
        }
        Math.sin(testAngle) => float vib;
        vib*(0.005*goalPG) => vib;
        //pG + vib => pG;     
    }

}

//Using a lumped loss scaler value for wall loss. TODO: implement more elegant filter for this, but so far, it works, so after everything else works.
class WallLossAttenuation extends Chugen
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
                 
    
    fun float calcConstants()
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
//function void scatteringJunction(WallLossAttenuation bronch1, WallLossAttenuation bronch2, WallLossAttenuation trachea, 
//DelayA bronch1Delay, DelayA bronch2Delay, DelayA tracheaDelay)
function float scatteringJunction2(DelayA bronch1, DelayA bronch2, DelayA trachea, 
DelayA bronch1Delay, DelayA bronch2Delay, DelayA tracheaDelay, float z0)
{ 
    
    bronch1 => Gain bronchus1Z => Gain add; 
    bronch2 => Gain bronchus2Z => add; 
    trachea => Gain tracheaZ => add; 
    
    //assume they have the same tube radius for now - I guess they prob. don't IRL
    1.0/z0 => bronchus1Z.gain;
    1.0/z0 => bronchus2Z.gain;
    1.0/z0 => tracheaZ.gain;
    2.0 => add.gain; 
    
    (1.0/z0 + 1.0/z0 + 1.0/z0) => float zSum; 
    
    add => Gain pJ; 
    1.0/zSum => pJ.gain; 
    
    Gain bronchus1Zout;
    bronchus1Zout.op(2); 
    pJ => bronchus1Zout;
    bronch1 => bronchus1Zout => bronch1Delay;
    
    Gain bronchus2Zout;
    bronchus2Zout.op(2);
    pJ => bronchus2Zout;
    bronch2 => bronchus2Zout => bronch2Delay;
    
    Gain tracheaZout;
    tracheaZout.op(2); 
    pJ => tracheaZout;
    trachea => tracheaZout => tracheaDelay;
    
    return z0;
}

class ScatteringJunction 
{
    Gain pJ; 
    float z0; 
    
    Gain bronchus1Z; 
    Gain bronchus2Z; 
    Gain tracheaZ; 
    Gain add;
    
    fun void updateZ0(float impedence)
    {
        impedence => z0; 
        (1.0/z0 + 1.0/z0 + 1.0/z0) => float zSum; 
        1.0/zSum => pJ.gain;
        
        1.0/z0 => bronchus1Z.gain;
        1.0/z0 => bronchus2Z.gain;
        1.0/z0 => tracheaZ.gain;
    }
    
    fun void scatter(DelayA bronch1, DelayA bronch2, DelayA trachea, 
    DelayA bronch1Delay, DelayA bronch2Delay, DelayA tracheaDelay, float impedence)
    { 
        
        bronch1 => bronchus1Z => add; 
        bronch2 => bronchus2Z => add; 
        trachea => tracheaZ => add; 
        
        //assume they have the same tube radius for now - I guess they prob. don't IRL
        1.0/z0 => bronchus1Z.gain;
        1.0/z0 => bronchus2Z.gain;
        1.0/z0 => tracheaZ.gain;
        2.0 => add.gain; 
        
        updateZ0(impedence); 
        add => pJ; 
    
        Gain bronchus1Zout;
        bronchus1Zout.op(2); 
        pJ => bronchus1Zout;
        bronch1 => bronchus1Zout => bronch1Delay;
    
        Gain bronchus2Zout;
        bronchus2Zout.op(2);
        pJ => bronchus2Zout;
        bronch2 => bronchus2Zout => bronch2Delay;
    
        Gain tracheaZout;
        tracheaZout.op(2); 
        pJ => tracheaZout;
        trachea => tracheaZout => tracheaDelay;
    }
}

//scattering junction implements two membranes at two bronchi, but evidence suggests basal condition is one syrinx membrane in the trachea
//this implements that. Discards 2nd syrinx bronchus... 
function void onlyOneNL(DelayA bronch1, DelayA bronch2, DelayA trachea, 
DelayA bronch1Delay, DelayA bronch2Delay, DelayA tracheaDelay)
{
    
}

// SIMPLE ENVELOPE FOLLOWER, by P. Cook
//modified by CDB Oct. 2022 to turn into function
fun OnePole envelopeFollower()
{
    
    // patch
    adc => Gain g => OnePole p => blackhole;
    // square the input
    adc => g;
    // multiply
    3 => g.op;
    
    // set pole position
    0.99 => p.pole;
    
    return p; 
}

//okay, this is just to test -- sanity debug check -- make sure -- obviously I can't keep this as a chugen, but probably
//in end result will not be using chugens at all.
//this filter is the sound that reflects back to the syrinx folds
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
//the h(z) to this is a bit unclear for me (checked again seems correct)
//need to test freq response
//this filter is the sound that radiates out from the trachea
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


//the envelope follower for the breath
envelopeFollower() @=> OnePole envF_breath;


//waveguides/tubes altered to model clarinet for an intermediate testable outcome before bronchus, trachea, junction are modeled
//used https://quod.lib.umich.edu/cgi/p/pod/dod-idx/efficient-simulation-of-the-reed-bore-and-bow-string.pdf?c=icmc;idno=bbp2372.1986.054;format=pdf
//& Cook's Real Sound Synthesis as a guide

//set globals
0.35 => float a;
7.0 => float L;
0.35 => float h;
0.0 => float period;
0.05 => float d; 

//from membrane to scattering junction - upper bronchus out
//SyrinxMembrane mem => DelayA delay => WallLossAttenuation wa; 
//SyrinxMembrane mem2 => DelayA delayMem2 => WallLossAttenuation waBronch2; 
SyrinxMembrane mem => DelayA delay; 
SyrinxMembrane mem2 => DelayA delayMem2; 

period::samp => delay.delay;
period::samp => delayMem2.delay;

//from the scattering junction out to the mouth
//DelayA tracheaOut => WallLossAttenuation tracheaWA => BirdTracheaFilter loop => blackhole;
DelayA tracheaOut => BirdTracheaFilter loop => blackhole;
period::samp => tracheaOut.delay;

//reflection back to scattering junction
loop  => Flip flip => DelayA tracheaBack;
period::samp => tracheaBack.delay;

//from trachea to sound out the 'mouth'
//tracheaWA => HPFilter hpOut => dac; //from trachea to sound out

tracheaOut => HPFilter hpOut => Dyno limiter =>  dac; //from trachea to sound out
limiter.limit();
10 => limiter.gain;


//reflection from scattering junction back to bronchus beginning -- 1st bronchus
DelayA bronch1Back => WallLossAttenuation waBronchBack;// => delay; 
Gain p1; 
waBronchBack => p1; 
mem => p1; //try prev. way
p1 => mem; 
p1 => delay; 
//p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
//1.0::samp => oz.delay; 
period::samp => bronch1Back.delay;

//reflection from scattering junction back to bronchus beginning -- 2nd bronchus
DelayA bronch2Back => WallLossAttenuation waBronch2Back; // => delayMem2; //reflection from trachea end back to bronchus beginning
Gain adder2; 
waBronch2Back => adder2; 
mem2 => adder2; //try prev. way
adder2 => mem2; 
adder2 => delayMem2;
//adder2 => DelayA oz2 =>  mem2; //the reflection also is considered in the pressure output of the syrinx
//1.0::samp => oz2.delay; 
period::samp => bronch2Back.delay;
//period::samp => bronch1Back.delay;

//Aaaand -- setup the scattering junction here to connect all the passage ways
ScatteringJunction junction; 
junction.scatter( delay, delayMem2, tracheaBack, bronch1Back, bronch2Back, tracheaOut, mem.z0);
//<<<"scat" + scatteringJunction2( delay, delayMem2, tracheaBack, bronch1Back, bronch2Back, tracheaOut, mem.z0 )>>>;

//initialize the global variables for a particular bird type
initGlobals();

//approximating from Smyth diss. 
setParamsForReflectionFilter();
      
hadrosaur(); //init for hadrosaur parameters
mouseEventLoopControllingAirPressure(); //MAIN UPDATE LOOP!!!


//--2/21 1p fixed reflection filter
 function void setParamsForReflectionFilter()
 {
     //https://asa-scitation-org.proxy.libraries.smu.edu/doi/pdf/10.1121/1.1911130
     //Benade -- acoustics in a cylindrical tube reference for w & ka

     //mem.c/(4*L) => float freq;
     //freq*2.0*Math.PI => float w;
     //(w/mem.c)*a => float ka; //from Smyth

     
     //0.5 => ka; //estimation of ka at cut-off from Smyth
     //find cutoff freq from this reference, then find ka
     //https://www.everythingrf.com/community/waveguide-cutoff-frequency#:~:text=Editorial%20Team%20%2D%20everything%20RF&text=The%20cut%2Doff%20frequency%20of%20a%20waveguide%20is%20the%20frequency,this%20frequency%20will%20be%20attenuated.
     //ka at the cut-off frequency of the waveguide
     //1.8412c/2pia
     //1.8412*mem.c/(2*Math.PI*a) => float cutOffFreq;
     //1.87754*mem.c/(2*Math.PI*a) => float cutOffFreq;
     //0.11*mem.c/(2*Math.PI*a) => float cutOffFreq;

     1.8412  => float ka; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
     //expected results -- eg. the wT frequency equation as given does not match the example 4.13(?), but the standard cutoff for metal waveguides does fine 
     //need to triple-check calculations, perhaps send an email to her.
     ka*(mem.c/a)*mem.T => float wT; //transition frequency wT
     //https://www.phys.unsw.edu.au/jw/cutoff.html#cutoff -- cut off of instrument with tone holes
     //https://hal.science/hal-02188757/document
          
     //magnitude of -1/(1 + 2s) part of oT from Smyth, eq. 4.44
     ka => float s; //this is kaj, so just the coefficient to sqrt(-1)
     #(-1, 0) => complex numerator;
     #(1, 2*s) => complex denominator;
     numerator / denominator => complex complexcHr_s;
     Math.sqrt( complexcHr_s.re*complexcHr_s.re + complexcHr_s.im*complexcHr_s.im )  => float oT; //magnitude of Hr(s)
     
     ( 1 + Math.cos(wT) - 2*oT*oT*Math.cos(wT) ) / ( 1 + Math.cos(wT) - 2*oT*oT ) => float alpha; //to determine a1 
     -alpha + Math.sqrt( alpha*alpha - 1 ) => float a1;
     (1 + a1 ) / 2 => float b0; 
     
     //using my own filter code for absolute clarity 
     //for the low-pass reflector -- birdtracheafilter class
     a1 => loop.a1;
     b0 => loop.b0; 
     
     //for the highpass output, from Smyth, again -- HPFilter class
     a1 => hpOut.a1; 
     b0 => hpOut.b0; 
     
     <<<"a:"+a>>>;
     <<<"oT:" + oT + " wT:" + wT>>>;
     <<<"a1:"+a1 + "   b0:"+b0>>>;
     
     <<<"*************">>>;

     //<<< "wT: " + wT + " oT: " + oT + " a1: "+ a1 + " b0: " + b0 >>>;
 }
 
 function float logScale(float in, float min, float max)
 {
     Math.log( max / min ) / (max - min)  => float b;
     max / Math.exp(b*max) => float a;
     return a * Math.exp ( b*in );     
 }
 
 function float expScale(float in, float min, float max)
 {
     //following, y = c*z^10
     // y = c* z^x
     Math.pow(max / min, (1.0/9.0)) => float z;
     min/z => float c;     
     c*(Math.pow(z, in)) => float res;
     return res; 
 }
 
 function void smallBird()
 {
     //set for a small bird
     //something is wrong with the reflection filter, there is a weird hole around 0.19 -- is it too small for the cutoff?
     //or the cutoff frequency doesn't hold for such small radii -- FIXED used the standard waveguide cutoff equation instead of Smyth's constant for ka... 
     //still -- merits further investigation.
     //0.19 => a; 
     //0.19 => h; 
     0.19 => a; 
     0.19 => h; 
     2.21 => L; 
     0.01 => d;  
     10.0 => hpOut.gain; 
     1 => mem.modT; 
     1.0 => mem.modPG; 
     1 => mem2.modT; 
     1.0 => mem2.modPG;    
     
     initGlobals(); 
 }
 
 function void duck()
 {
     //set for a larger bird, currently sounds duck-like
     0.35 => a; 
     0.35 => h; 
     6.55 => L; 
     0.01 => d;      
     1.0 => hpOut.gain; 
     10.0 => mem.modT; 
     10.0 => mem.modPG; 
     10.0 => mem2.modT; 
     10.0 => mem2.modPG; 
         
     initGlobals(); 
 }
 
 //still too much resonance? wall filters?
 function void hadrosaur()
 {
     4.5 => a; 
     4.5 => h; 
     116.0 => L; //~153.7 Hz - resonance    
     //0.1285714285714286 => d;  
     5.0 => d;  

     0.01 => hpOut.gain; 
     10000.0 => mem.modT; 
     80.0 => mem.modPG; 
     10000.0 => mem2.modT; 
     100.0 => mem2.modPG; 
     
     initGlobals(); 
 }
 
 function void initGlobals()
 {
     //init the globals
     a => mem.a;
     L => mem.L; 
     h => mem.h;
     d => mem.d;
     
     a => mem2.a;
     L => mem2.L; 
     h => mem2.h;
     d => mem2.d;
     
     mem.initTension();
     mem2.initTension();
     mem.initZ0(); 
     mem2.initZ0(); 
     junction.updateZ0(mem.z0); 

     a => waBronchBack.a;
     L*2.0 => waBronchBack.L; //change for when trachea and brochus are different
     
     a => waBronch2Back.a;
     L*2.0 => waBronch2Back.L; //change for when trachea and brochus are different
          
     waBronch2Back.calcConstants();  
     waBronchBack.calcConstants();  

     34740 => float c; // in m/s
     c/(2.0*L) => float LFreq; // -- the resonant freq. of the tube (?? need to look at this)
     ( (0.5*second / samp) / (LFreq) - 1) => period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
     
     period::samp => delay.delay;
     period::samp => delayMem2.delay;
     period::samp => tracheaOut.delay;
     period::samp => tracheaBack.delay;
     period::samp => bronch2Back.delay;
     period::samp => bronch1Back.delay;
     
     setParamsForReflectionFilter(); 
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
    0 => float max1; 
    while( true )
    {
        // wait on HidIn as event
        //hi => now;
        
        1::ms => now; 
        envF_breath.last() => float ctrlValue;
        //<<< ctrlValue >>>;

        //<<<max1>>>;
        //if(whichBird == 0)
        //{
            float p;
            float pG1; 
            float tot; 
            if (ctrlValue!=0)
            {
                ctrlValue*1000.0 => tot;
                expScale(tot, 1.0, 10.0 ) => p;
                p-0.8=>p; 
                Math.max(p, 0) =>p; 
                //ctrlValue/10.0 => totVal;
                
            }
            p * 100000000.0 => pG1;
            Math.min(pG1, 250000) => pG1;
            mem.changePG(pG1); 
            mem2.changePG(pG1);
            Math.max(max1, p) => max1;
            //<<<"p: " + p +" ctrlValue: " + ctrlValue>>>;
        //}

        
        // messages received
        if( hi.recv( msg ) )
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
                
                float maxPG;
                if(whichBird > 0)
                    60 => maxPG; //before was 60 -- let's see
                else
                    2000 => maxPG;
                //msg.scaledCursorY * maxPG => mem.pG;
                // <<< "totVal b4 scale:", totVal >>>;
                
                totVal * maxPG => float pG; 
                //logScale(totVal, 0.0000001, maxPG ) => totVal; 
                
                
                if(whichBird == 0)
                {
                    float p;
                    if (totVal!=0)
                    {
                        totVal*10.0 => totVal;
                        expScale(totVal, 1.0, 10.0 ) => p;
                    }
                    p * pG * 7000.0 => pG;
                    Math.min(pG, 200000) => pG;
                    //<<<p>>>;
                }
/*
                mem.changePG(pG); 
                mem2.changePG(pG); 
*/

                //<<< "max delta:", max >>>;
                //<<< "pG:", mem.pG >>>; //turn this back on
                // <<< "totVal:", totVal >>>;
                
                logScale( msg.scaledCursorX, 0.0000001, 1.0 ) => float scaledX; 
                logScale( msg.scaledCursorY, 0.0000001, 1.0 ) => float scaledY; 

                
                
                //we'll say default tension until 3pg
                if(pG < 3.059 && whichBird > 0)
                {  
                    mem.changeTension(mem.initT); 
                    mem2.changeTension(mem2.initT); 

                }
                else
                {
                    /*  Duck-like settings
                    
                    //correlate pG with tension
                    mem.initT => float t;
                    900.0-mem.initT => float scale;
                    msg.scaledCursorY-(3.059/maxPG) => float mult; 
                    
                    //add up to 200 n/cm3 according to x
                    scaledX * 1000.0 => float Tadd;
                    
                    //Tadd => t;
                    t + mult*scale + Tadd => t; 
                    //t + mult*scale => t; 
                    
                    mem.changeTension(t); 
                    <<< "tension:", t >>>;
                    
                    */
                    
                    //correlate pG with tension
                    mem.initT => float t;
                    1500.0-mem.initT => float scale;
                    msg.scaledCursorY-(3.059/maxPG) => float mult; 
                    
                    //add up to 200 n/cm3 according to x
                    scaledX * 3000.0 => float Tadd;
                    
                    //Tadd => t;
                    if(whichBird > 0){
                        t + mult*scale + Tadd => t; 

                    }
                    else { //hadrosaur
                        mem.initT*0.5 + msg.scaledCursorY*mem.initT*5.0 => t;
                        <<<"tension: " + t>>>;
                        //msg.deltaX
                        //t + mult*scale + Tadd => t; 
                        //mem.initT => t; 
                        //<<<"not changing tension">>>;
                    }

                    //t + Tadd => t; 
                    
                    mem.changeTension(t);
                    mem.updateTensionAndW(); 
                    mem2.changeTension(t); 
                    mem2.updateTensionAndW(); 
                    
                    (mem.dT + mem.diff)*mem.T*mem.modT  => mem.dT; 
                  (mem.dT + mem.diff)*mem.T*mem.modT  => mem2.dT; 
                  mem.curT + mem.dT => mem.curT;
                  mem.curT + mem.dT => mem2.curT;

                  
 // <<< "dT: "+mem.dT + "diff: " + mem.diff +   " dT: " + mem.dT +" goalT: " + mem.goalT + " curT:"+ mem.curT+ " t: " + Math.sqrt( (5*t) / (mem.pM*mem.a*mem.h*mem.d) )  + " freq:", mem.w[0]/(2*pi) + " freq2:", mem.w[1]/(2*pi) >>>; //--> change the tension
                    hpOut.last() => float trachP1; 
                    Math.max(trachP1, max) => max;
                    //<<< "outAmp: "+ max >>>;
                }
            }
            else if( msg.isButtonDown() )
            {
                //<<< "down:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
                //change which model 
            /*    if( whichBird == 0)
                {
                    whichBird++; 
                    smallBird();
                } 
                else if( whichBird == 1)
                {
                    whichBird++; 
                    duck();
                } 
                else 
                {
                    0 => whichBird;
                    hadrosaur(); 
                }
                */
            }    
        }  
    }  
}