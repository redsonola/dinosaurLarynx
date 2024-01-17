//Model derived from: 
//1. https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=6a2f5db63fa313965386c88dc6e3a71b19fd5f2e#page=25
//2. https://findresearcher.sdu.dk/ws/portalfiles/portal/50551636/2006_Zaccarelli_etal_ActaAcustica.pdf
//3. https://hal.science/hal-02000963/document -- previous model that this is based on
//4. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2607454/#bib46 (the elemans paper -- other 2 are references to complete the model)

//a good perspective of the state of bird vocal modeling in.... 2002
//https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=dbca9e2ef474525b4b9417ec92daf0ae88191a97

//implementation of IIshizaka & Flanagan's 2 mass vocal model, for reference
//https://gist.github.com/kinoh/5940180

//check reference list
//biorxiv.org/content/biorxiv/early/2019/10/02/790857.full.pdf

//found the dissertation with all the equations:
//https://edoc.hu-berlin.de/bitstream/handle/18452/17159/zaccarelli.pdf?sequence=1

//Note look at: 
//Riede et al., 2004

//2010 paper on the oscine bird
//http://www.lsd.df.uba.ar/papers/PhysRevE_comp_model.pdf


/*

[1]	D. N. During and C. P. H. Elemans. Embodied Motor Control of Avian Vocal Production. In Vertebrate Sound Production and Acoustic Communication. Springer International Publishing, 119?157, 2016. https://doi.org/10.1007/978-3-319-27721-9_5

*/

//The evolution of the syrinx: An acoustic theory -- 2019 paper with up to date computational modeling 
//https://journals.plos.org/plosbiology/article/file?id=10.1371/journal.pbio.2006507&type=printable

//Sensitivity of Source?Filter Interaction to Specific Vocal Tract Shapes
//https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9390861/

//In situ vocal fold properties and pitch prediction by dynamic actuation of the songbird syrinx
//https://www.nature.com/articles/s41598-017-11258-1.pdf

//https://arc.aiaa.org/doi/abs/10.2514/6.2018-0578

//universal methods of sound production in birds
//https://www.nature.com/articles/ncomms9978.pdf

//Zacharelli 2008, "the syrinx i sbrought into a phonatory position by two paired syringeal muscles; 
//the m. sternotrachealis (ST) - he ST moves the entire syrinx downward
//and m. tracheolateralis (TL) - TL directly affects position in the LTM  "
//Lateral Vibratory Mass (LVM) instead of Lateral Tympaniform Membrane (LTM) as it is not thin in ring doves.

//cont. Zaccahrell ch. 4 notes
//When looking at the forces acting on the LVM (Fig. 4.1b), it becomes clear that any pressure differences between the air sac surrounding the syrinx (the interclavicular air sac) and syringeal lumen causes a net force to act on the LVM. This so-called transmural pressure Pt affects the tension in the membrane (Bertram and Pedley, 1982; Bertram, 2004). 
//Picas -- pressure in the interclavicular air sac (icas) -- above syrinx lvm
//Ptcas -- pressure in the caudal thoracic air sac (ctas) -- below syrinx lvm
//Pt =Picas - Pctas

//Considering the mechanics, the LVM tension is affected by both 
//1) the transmural stress caused by a pressure differential between the bronchus and ICAS and 
//2) the stress exerted by muscles.
//both the transmural pressure and TL stress affect tension in the LVM.

//If we look at the forces acting on the syrinx membranes (Fig. 4.1b), the most important physiological control parameters are 
//1) the bronchial-tracheal pressure gradient, 
//2) the transmural pressure difference and 
//3) the stress exerted by syringeal muscles.

//TODO: implement graphs on pg. 73 of Zaccharelli for Ps, Pt, Ptl

//Syrinx Membrane - note: it works with 1/2 the Ps value per the paper? What is going on, then?
class RingDoveSyrinxLTM extends Chugen
{
    //time steps, for discrete real-time implementation
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    (T*1000.0)/2.0 => float timeStep; //this is for integrating smoothly, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert

    //membrane displacement
    [0.0, 0.0] @=> float x[]; 
    [0.0, 0.0] @=> float dx[]; 
    [0.0, 0.0] @=> float d2x[]; 
    [0.0, 0.0] @=> float F[]; //force
    0.0017 => float m; //mass, table C.1
        
    //damping and stiffness coefficients 
    0.0012 => float r; //damping, table C.1
    0.0022 => float k; //stiffness -- orig. 0.02 in fig. 3.2 zaccharelli -- now back to original-ish? table C.1
    0.006 => float kc; //coupling constant, table C.1 (before, 0.005)
    
    [0.0, 0.0] @=> float I[]; //collisions
    
    //biological parameters of ring dove syrinx, in cm
    0.15 => float w; //trachea width
    0.3 => float l; //length of the trachea, 4.1 table
    0.003 => float a01; //lower rest area
    0.003 => float a02; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx
    
    //time-varying (control) tension parameters (introduced in ch 4 & appendix C)
    19.0 => float Ptl; //stress due to the TL tracheolateralis (TL) - TL directly affects position in the LTM -- probably change in dinosaur.
    0.0 => float minPtl; 
    20.0 => float maxPtl; 
    -0.03 => float a0min; 
    0.01 => float a0max; 
    a0max - a0min => float a0Change; 
    
    //time-varying (input control) parameters Q, which reflect sum of syringeal pressures
    0.8 => float Qmin; 
    1.2 => float Qmax;
    Qmin => float Q; //F(t) = Q(t)F0
    -0.3 => float Pt; //-1 to 0.5 using CTAS, normalized to 1, max but usually around 0.5 max -- from graph on p. 70, Pt = PICAS - PCTAS (max 3.5), 
    Pt + Ptl => float Psum;
    0.0 => float minPsum; 
    20.0 => float maxPsum; 
    Qmax - Qmin => float Qchange;
    
    //adding an extra zero -- previous --> 0.4, 0.24, 0.28
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
    
    2.0*l*w => float a0; //a0 is the same for both masses since a01 == a02

    //pressure values - limit cycle is half of predicted? --> 0.00212.5 to .002675?
    //no - 0.0017 to 0.0031 -- tho, 31 starts with noise, if dividing by 2 in the timestep
    0.04 => float Ps; //pressure in the syringeal lumen, 
    //0.004 is default Ps for this model but only 1/2 of predicted works in trapezoidal model for default params (?)
    //0.02 is the parameter for fig. C3 & does produce sound with the new time-varying tension/muscle pressure params
    
    //geometry
    d1 + (d2/2) => float dM; //imaginary horizontal midline -- above act on upper mass, below on lower
    
    //geometries to calculate force
    0.0 => float a1; 
    0.0 => float a2; 
    0.0 => float aMin;
    0.0 => float zAMin; 
    0.0 => float aM;  
    0.0 => float a3; 

    //collision point ordinates
    0.0 => float minCPO; //min. collision point ordinate -- cpo
    0.0 => float cpo1; 
    0.0 => float cpo2; 
    0.0 => float cpo3; 
        
    0.0 => float dU;
    
    0.00113 => float p; //air density
    
    //Steineke & Herzel, 1994  --this part was not clear there but--->
    //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
    //https://doi.org/10.1063/1.166078
    //confirmed in Herzel & Steineke 1995 Bifurcations in an asymmetric vocal-fold model 
    3.0 * k => float c1; 
    3.0 * k => float c2; 

    fun void updateU()
    {
        if(aMin > 0)
        {
            //breaking up the equation so I can easily see order of operations is correct
            //2*l*Math.sqrt((2*Ps)/p) => float firstMult; 
            2*l*Math.sqrt((2*Ps)/p) => float firstMult;
            heaveisideA(a2-a1, a1)*dx[0] => float firstAdd; 
            heaveisideA(a1-a2, a2)*dx[1]=> float secondAdd;
            
            firstMult*(firstAdd + secondAdd) => dU;
        }
        else
        {
           0 => dU; //current dU is 0, then have to smooth for integration just showing that in the code
        }                
    }
    
    fun void updateX()
    {
       m/Q => float mt; //time-varying mass due to muscle tensions, etc.
       k*Q => float kt; //time-varying stiffness due to muscle tensions, etc.
        
       //update d2x/dt
       timeStep * ( d2x[0] + ( (1.0/mt) * ( F[0] - r*dx[0] - kt*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
       timeStep * ( d2x[1] + ( (1.0/mt) * ( F[1] - r*dx[1] - kt*x[1] + I[1] - kc*( x[1] - x[0] )) ) ) => d2x[1];  
              
       for( 0=>int i; i<x.cap(); i++ )
       {
           //update dx, integrate
           dx[i] => float dxPrev;
           dx[i] + d2x[i] => dx[i];
           
           //update x, integrate again
           x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 
       }
    }

//Not using right now...... but may use later as more general purpose
//using -- 1/4/2024

fun float syringealArea(float z)
{
    if( z >=0 && z<=d1)
        return ((a1-a0)/d1)*z + a0;
    else if( z > d1 && z <= d1+d2 )
        return ((a2-a1)/d2)*(z-d1) + a1;
    else if( z > d1+d2 && z <= d1+d2+d3 )
        return ((a0-a2)/d3)*(z-d1-d2) + a2;
    else return 0.0; 
}


/*
//this should be equivalent to the above, but using here right now to completely avoid magical thinking
fun float syringealArea(float z)
{
    if( z==0 || z==(d1+d2+d3) )
        return a0; 
    else if(z == d1)
        return a1; 
    else if(z == (d1+d2))
        return a2; 
    else if(z == dM )
        return aM; 
    else
    {
        <<< "Error! Called area for unkown value. Need to modify code." >>>;
        return 0.0; 
    }
}
*/

  
    fun float heaveiside(float val)
    {
        if( val > 0 )
        {
            return 1.0;
        }
        else 
        {
            return 0.0;
        }
     }
     
     //from Steinecke, et. al  1994 & 1995 --> a smoothing heaveside not sure if this is important yet.
     fun float heaveisideA(float val, float a)
     {
         if( val > 0 )
         {
             return Math.tanh(50*(val/a)); 
         }
         else 
         {
             return 0.0;
         }
     }


     fun void updateCPO()
     {
         //find all the CPOs
         (a0*d1)/(a0-a1) =>  cpo1; 
            
         d1 - ( (a1*d2)/(a2-a1) ) =>  cpo2; 
         
         d1 + d2 - ( (a2*d3)/(a0-a2) ) =>  cpo3;  
         
     }

     //replace with equation from diss.
     fun float defIForce(float z0, float z1)
     {         
         
         syringealArea(z0) => float aZ0;
         syringealArea(z1) => float aZ1;

         if( aMin <=0 ) //closed configuration
         {             
             //find min c.p.o
             updateCPO();
             0.0 => float min0; 
             Math.min(min0, cpo1) => min0; 
             Math.min(min0, cpo2) => min0;  
             Math.min(min0, cpo3) => min0; 
        
             //Zaccarelli, 2009, p110 -- for forces F2, in closed configuration
             if(   ( ( z0==d1 ) && z1==dM  ) || ( z0==dM && z1==(d1+d2) )   ) //it's F2
             {
                 if( a1 <= 0 && min0==cpo1 && cpo1 < z1) //case 4
                 {
                     return 0.0;
                 }
                 else if( ( a1 > 0 ) && a1 <= Math.fabs(a2)  && min0==cpo2 && cpo2 <= dM ) //case 3a
                 {
                     return 0.0; 
                 }
                 else if( a1 > 0  && a1 > Math.fabs(a2) && min0==cpo2 && cpo2 > dM  ) //case 3b
                 {
                     return l*Ps*( d2/2 * ( (a1+a2)  / (a1-a2) ) ); 
                 }
                 else return l*Ps*( Math.min(min0, z1)  - z0); 
             }
             else //it's F1
             {
                 if( ( a1 > 0 ) && a1 <= Math.fabs(a2) && min0==cpo2 && cpo2 <= dM ) //case 3a
                 {
                     return l*Ps*( d1 + d2*( a1/( a1-a2 ) ) );
                 }
                 else if( a1 > 0  && a1 > Math.fabs(a2) && min0==cpo2 && cpo2 > dM  ) //case 3b
                 {
                     return l*Ps*dM;
                 }
                 else if ( a1 <= 0 && min0==cpo1 && cpo1 < z1) //case 4
                 {
                     return l*Ps*d1*( a0/(a0-a1));
                 }
                 else 
                 {
                     return l*Ps*( Math.min(min0, z1)  - z0); 
                 }
             }
         }
         else //open configuration
         {
             if(  ( ( ( z0==d1 ) && z1==dM  ) || ( z0==dM && z1==(d1+d2) ) ) && (zAMin == z0)  ) //it's F2 & case 1
             {
                 return 0.0; 
             }
             else return l*Ps*(z1 - z0)*(1 - ( (aMin*aMin)/(aZ0*aZ1) )  );
         }
     }
     
     fun float updateForce()
     {
         //find current areas according to p. 106, Zaccarelli, 2009
         a01/(2*l) => float x01;
         a02/(2*l) => float x02;
         l*( x[0] + x01 + x[1] + x02 ) => aM; //the 2.0 cancels out
         
         2*l*(x[0]+x01) => a1;
         2*l*(x[1]+x02) => a2;         

         if( a1 < a2 )
         {
             a1=> aMin;
             d1 => zAMin;
         }
         else
         {
             a2 => aMin;
             d1+d2 => zAMin;             
         }   
         
         defIForce( 0, d1 ) + defIForce(d1, dM) => F[0];
   //      defIForce(dM, d1+d2) => F[1]; //trying
         defIForce(dM, d1+d2) => F[1]; //modifying in terms of equation presented on (A.8) p.110

     }
     
     //note: is it worth implementing eq. A.5 for pressure? on p. 108 Zaccarelli
     
     //TODO: recheck this w/table
     fun void updateCollisions()
     {           
           
         //this is what makes everything blow up... need to look at this.
         dM - cpo1 => float L1; 
         cpo3 - dM => float L2; 
         
         if( a1>=0 && aM >=0)
         {
             0.0 => I[0];
         }
         else if( a1>=0 && aM < 0 )
         {
             ( -c1/(4*l) )*aM => I[0];
         } 
         else
         {
             ( -c1/(4*l) )*( a1 + ( (aM*d2)/( 2*L1 ) ) ) => I[0];
         }
         
         if( a2>=0 && aM >=0)
         {
             0.0 => I[1];
         }
         else if( a2>=0 && aM < 0 )
         {
             ( -c2/(4*l) )*aM => I[1];
         }
         else
         {
             ( -c2/(4*l) )*( a2 + ( (aM*d2)/( 2*L2 ) ) ) => I[1];                 
         }
     }
     
     
     //update areas due to syringeal pressure (implements Zaccharelli, 2008 Ch. 4 & Appendix C)
     fun void updateRestingAreas()
     {
         Ptl*(a0Change/maxPtl) + a0min => a01; 
         Ptl*(a0Change/maxPtl) + a0min => a02; 
     }
     
    fun void updateQ()
    {
        Ptl + Pt => Psum; //update Psum first
        Psum*( Qchange/maxPsum ) + Qmin => Q; //now update Q
    }
    
    fun float tick(float in)
    {

        updateCollisions();
        updateX();
        updateForce();
        updateU(); 
        updateRestingAreas();
        updateQ();
        
        return dU; 
    }
}

RingDoveSyrinxLTM ltm => Dyno limiter => dac; 

//3::second => now; //3 minutes of sound
//<<<ltm.Psum>>>;

// create trill 
Envelope envPs => blackhole; 
0.0 => envPs.value; 
0.0035 => envPs.target; 
1::second => envPs.duration;

SinOsc oscPt => blackhole;
35 => oscPt.freq; //just eyeballing fig. 4.3 in Zacharelli
Envelope envSinPt => blackhole; 
limiter.limit(); 

Envelope envPtl => blackhole; 
0 => envPtl.value;
15 => envPtl.target;

Envelope envPt => blackhole; 
-1 => envPt.value;
0.5 => envPt.target;


 
now + 10::second => time later; //swoop for 6 seconds

while( now < later)
{
    //Ps
   
    envPs.value() => ltm.Ps;
    envPtl.value() => ltm.Ptl; 
    envPt.value() => ltm.Pt;
    
    if( envPs.value() == envPs.target() )
    {
        if( ltm.Ps == 0.0035 )
        {
            0.001 => envPs.target;
            0.0012/0.0035 * 15 => envPtl.target;
            ((0.0012/0.0035)*1.5)  - 1.0 => ltm.Pt;
            
        }
        else if( ltm.Ps == 0.01  )
        {
            0.0035 => envPs.target;
            15 => envPtl.target;
            -1.0 => ltm.Pt;
        }
    }
   // ltm.Ps/0.013 * 20 => ltm.Ptl;
    
    

//    later - now => dur ptE; 
//    ptE % 0.5::second => ptE; //truncate
//    if( ptE < 0.4::second*0.5 )
//    {
//        20 => oscPt.freq;
//    }
//    else 
//    {
//        3 => oscPt.freq;
//    }
//    (oscPt.last()+1.0)/2.0 * 1.0 => ltm.Ptl;
//    oscPt.last() *  0.001   => ltm.Pt;
    //(oscPt.last()+1.0)/2.0 *  0.02 + 0.02 => ltm.Ps;


    //update time inside the loop
    1::samp => now; 
}



//mouseEventLoopControllingAirPressure();

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

                logScale( msg.scaledCursorX, 0.000000001, 1.0 ) => float scaledX; 
                logScale( msg.scaledCursorY, 0.000000001, 1.0 ) => float scaledY;
                
                 
                
               //msg.scaledCursorX * (0.01225-0.010954) + 0.010954 => ltm.Ps;
                //msg.scaledCursorX * (0.01225-0.007954) + 0.007954 => ltm.Ps;

               //(msg.scaledCursorY*1.5)  - 1.0 => ltm.Pt;
               //(1.0- msg.scaledCursorY) * 19.0 => ltm.Ptl;
               //<<<ltm.Ps>>>;
               
                //msg.scaledCursorX * (0.01225-0.010954) + 0.010954 => ltm.Ps;
                msg.scaledCursorX * (0.012-0.000954) + 0.000954 => ltm.Ps;

               (msg.scaledCursorY*1.5)  - 1.0 => ltm.Pt;
               (1.0- msg.scaledCursorY) * 20.0 => ltm.Ptl;
               <<<ltm.Ps>>>;
                
                
            }
                
                
            
        }  
        1::samp => now;
    }  

}

function float logScale(float in, float min, float max)
{
    Math.log( max / min ) / (max - min)  => float b;
    max / Math.exp(b*max) => float a;
    return a * Math.exp ( b*in );
}


/*
<<<ltm.defIForce(0, ltm.d1)>>>;
<<<ltm.defIForce(ltm.d1, ltm.dM)>>>;
<<<ltm.defIForce(ltm.dM, ltm.d2)>>>;
<<<"a1:" + ltm.a1>>>;
<<<"a2:" + ltm.a2>>>;
<<<"aMin:" + ltm.aMin>>>;
<<<"cpo1:" + ltm.cpo1>>>;
<<<"cpo2:" + ltm.cpo2>>>;
<<<"cpo3:" + ltm.cpo3>>>;
<<<"d1:" + ltm.d1>>>;
<<<"d2:" + ltm.d2>>>;
<<<"d3:" + ltm.d3>>>;
*/


<<< "**********************************" >>>;
/*
FileIO fout;

// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/out3.txt", FileIO.WRITE );

// test

if( !fout.good() )
{
    cherr <= "can't open file for writing..." <= IO.newline();
    me.exit();
}
*/


 //   "x[0]"  + "," + "x[1]" +"," + "dx[0]"  + "," + "dx[1]" + "," + "a1" + "," + "a2" + "," + "dU"  + ", "+"F[0]" + "," + "F[1]" + "," + "I[0]" + "," + "I[1]" +"\n" => string output; 
//    fout.write( output );



/*
while(now - start < 10::ms)    
{
  //  <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    //<<< ltm.dU  + " , " + ltm.x[1] + " , " + ltm.x[0] +" , " +  ltm.d2x[1] + " , " + ltm.F[1] + " , " + ltm.I[1] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
   // <<<ltm.x[0] + " , " +  ltm.x[1] + " , " + ltm.cpo1 + " , " + ltm.cpo2 + " , "+ ltm.cpo3 + " , " + ltm.I[0] + " , " + ltm.I[1] + " , " + ltm.zM >>>;
 //   ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," 
//        + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
        
  //      <<< ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" >>>;
     
    
    
        ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.F[0] + "," + ltm.F[1]+ ","  + ltm.I[0] + "," + ltm.I[1]  + "," +  "\n" => string output; 
  //  + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
    
    <<< ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.F[0] + "," + ltm.F[1] + ","+ ltm.I[0] + "," + ltm.I[1] + "\n" >>>;
    fout.write( output ); 
    
    
    fout.write( output ); 

    1::samp => now;   
}  


// close the thing
fout.close();
*/

//TODO for tomorrow:
//1. Check expectations, this is close -- but I only skimmed that part
//2. recheck collision equations --> check
//3. recheck parameters and initial conditions --> check
//4. recheck forces agains --> check




