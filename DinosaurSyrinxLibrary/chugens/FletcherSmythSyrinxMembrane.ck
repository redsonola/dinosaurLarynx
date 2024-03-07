//Syrinx Membrane
//Models the oscillation of the syrinx membrane in response to air pressure (pG) & and tension
//Uses Fletcher(1988), Fletcher(2014), and Smyth(2002-4) for equations and guide.

public class SyrinxMembrane extends Chugen
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
        
        if( x > 0.0 ) //force if open
        {
            a*h*(p0 + p1) - (2.0*p*U*U*h)/(7.0*Math.pow(a*x, 1.5)) => F; //-- Smyth 
            //memArea* ( ( pressureDiff ) - ( UFactor/overArea  ) ) => F; //fletcher
            
        }
        else 0.5*a*h*(p0 + p1) => F; //force if closed
        
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
        if(diff != 0)
        {            
            (dT + diff)*T*modT => dT ; 
            curT + dT => curT; 
            
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
