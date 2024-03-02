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

//Synthetic Birdsongs as a Tool to Induce, and Iisten to, Replay Activity in Sleeping Birds
//https://www.frontiersin.org/articles/10.3389/fnins.2021.647978/full

//Nonlinear dynamics in the study of birdsong
//https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5605333/

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

//TODO: implement graphs on pg. 73 of Zaccharelli for Ps, Pt, Ptl DONE -ish -- used for interactive ranges for mouse movement

//NOTE: Dove coo is at 600Hz, highest note is 600Hz -- tested it quick and dirty, playing along with SinOsc @ 600HZ.

//global parameter -- speed of sound
347.4 => float c; // in m/s

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
    
    //********* constants that change during modeling the coo!!! 2/2024 Table C.1 p. 134 ************
    0.0017 => float m; //mass, table C.1
    0.022 => float k; //stiffness -- orig. 0.02 in fig. 3.2 zaccharelli -- now back to original-ish? table C.1
    0.006 => float kc; //coupling constant, table C.1 (before, 0.005)
    0.0012 => float r; //damping, table C.1 // 0.0012 => float r;
    
    //biological parameters of ring dove syrinx, in cm -- ***change during coo! Table 4.1, p76
    0.15 => float w;//1/2 trachea width
    2*w => float a;//full trachea width
    0.32 => float l; //length of the trachea, 4.1 table **changed
    0.003 => float a01; //lower rest area
    0.003 => float a02; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx

    //adding an extra zero -- previous --> 0.4, 0.24, 0.28
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
        
    //damping and stiffness coefficients 
    //0.0022 => float k; //stiffness -- orig. 0.02 in fig. 3.2 zaccharelli -- now back to original-ish? table C.1
    //0.006 => float kc; //coupling constant, table C.1 (before, 0.005)
    

    [0.0, 0.0] @=> float I[]; //collisions
    
    
    //time-varying (control) tension parameters (introduced in ch 4 & appendix C)
    19.0 => float Ptl; //stress due to the TL tracheolateralis (TL) - TL directly affects position in the LTM -- probably change in dinosaur.
    0.0 => float minPtl; 
    20.0 => float maxPtl; 
    
    //changing Ptl
    Ptl => float goalPtl;//the tension to increase or decrease to    
    0.0 => float dPtl; //change in tension per sample -- only a class variable so can check value. 
    5.0 => float modPtl; //a modifier for how quickly dx gets added
    
    //more time-varying parameters
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
    
    //changing Pt
    Pt => float goalPt;//the tension to increase or decrease to    
    0.0 => float dPt; //change in tension per sample -- only a class variable so can check value. 
    5.0 => float modPt; //a modifier for how quickly dx gets added
    
    2.0*l*w => float a0; //a0 is the same for both masses since a01 == a02

    //pressure values - limit cycle is half of predicted? --> 0.00212.5 to .002675?
    //no - 0.0017 to 0.0031 -- tho, 31 starts with noise, if dividing by 2 in the timestep
    0.0045 => float Ps; //pressure in the syringeal lumen, 
    
    //changing Ps
    Ps => float goalPs;//the tension to increase or decrease to    
    0.0 => float dPs; //change in tension per sample -- only a class variable so can check value. 
    50.0 => float modPs; //a modifier for how quickly dx gets added
    
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
    0.0 => float U;
    
    0.00113 => float p; //air density
    
     //***adding the input pressure to the force -- 2/29/2024
    //**********from the Fletcher model, adding back vocal tract effects
    0 => float inputP; //this is reflection from vocal tract
    (p*c*100)/(pi*a*a) => float z0; //impedence of brochus --small compared to trachea, trying this dummy value until more info 
    z0/6   => float zG; //NOT USED erase --> an arbitrary impedance smaller than z0, Fletcher
    0.0 => float pAC; //reflected pressure from the vocal tract after coupling - incl. impedence, etc.

    //Steineke & Herzel, 1994  --this part was not clear there but--->
    //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
    //https://doi.org/10.1063/1.166078
    //confirmed in Herzel & Steineke 1995 Bifurcations in an asymmetric vocal-fold model 
    3.0 * k => float c1; 
    3.0 * k => float c2; 

    fun void updateU(float Ps)
    {
        //find du
        if(aMin > 0)
        {
            //breaking up the equation so I can easily see order of operations is correct
            2*l*Math.sqrt((2*Ps)/p) => float firstMult;
            heaveisideA(a2-a1, a1)*dx[0] => float firstAdd; 
            heaveisideA(a1-a2, a2)*dx[1]=> float secondAdd;
            
            firstMult*(firstAdd + secondAdd) => dU;
        }
        else
        {
           0 => dU; //current dU is 0, then have to smooth for integration just showing that in the code
        }     
        
        //find U for vocal tract coupling -- more precise than integrating
        Math.sqrt((2*Ps)/p) => float sq; 
        sq*aMin*heaveiside(aMin) => U;           
    }
    
    //couple the input pressue to this syrinx membrane model
    fun void updatePAC() //Lous, et. al., 1998 - moved this to coupler class
    {
        z0*U + 2*inputP => pAC;
    }
    
    fun void updateX()
    {
        //for controlling muscle tension parameters
       m/Q => float mt; //time-varying mass due to muscle tensions, etc.
       k*Q => float kt; //time-varying stiffness due to muscle tensions, etc.
        
       //update d2x/dt
       timeStep * ( d2x[0] + ( (1.0/mt) * ( F[0] - r*dx[0] - kt*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
       timeStep * ( d2x[1] + ( (1.0/mt) * ( F[1] - r*dx[1] - kt*x[1] + I[1] - kc*( x[1] - x[0] )) ) ) => d2x[1];  
              
       for( 0=>int i; i<x.size(); i++ )
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
     
     //from Steinecke, et. al  1994 & 1995 --> a smoothing heaveside not sure if this is important yet. <--NOPE!!!
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
     
     //finds force 1 
     fun float forceF1(float min0, float Ps)
     {
         if( aMin <=0 ) //closed configuration
         {
             if( ( a1 > 0 ) && a1 <= Math.fabs(a2) )// && min0==cpo2 && cpo2 <= dM ) //case 3a
             {
                 return l*Ps*( d1 + d2*( a1/( a1-a2 ) ) );
             }
             else if( a1 > 0  && a1 > Math.fabs(a2) )// && min0==cpo2 && cpo2 > dM  ) //case 3b
             {
                 return l*Ps*dM;
             }
             else if ( a1 <= 0)// && min0==cpo1 && cpo1 < d1) //case 4
             {
                 return l*Ps*d1*( a0/(a0-a1));
             }
             else 
             {
                 return (l*Ps*( Math.min(min0, d1)  - 0)) + (l*Ps*( Math.min(min0, dM)  - d1)); //check this
             }
         }
         else //open configuration
         {
             if (a2 > a1 )  //divergent - || ( zAMin == d1 )
             {
                 return l*Ps*d1*(1 - (( a1*a1 )/(a0*a1)) );
             }
            else //convergent
            {
                d1*(1 - ( (a2*a2)/(a0*a1) )  ) => float part1; 
                (d2/2)*(1 - ( (a2*a2)/(aM*a1) ))  => float part2;
                return l*Ps * ( part1 + part2 );
            }
         }
     }
     
     fun float forceF2(float min0, float Ps)
     {
         if( aMin <= 0) //closed configuration
         {
             if( a1 <= 0)// && min0==cpo1 && (cpo1 < d1)) //case 4
             {
                 return 0.0;
             }
             else if( ( a1 > 0 ) && (a1 <= Math.fabs(a2)))//  && min0==cpo2 && cpo2 <= dM ) //case 3a
             {
                 return 0.0; 
             }
             else if( a1 > 0  && a1 > Math.fabs(a2))// && min0==cpo2 && cpo2 > dM  ) //case 3b
             {
                 return l*Ps*( d2/2 * ( (a1+a2)  / (a1-a2) ) ); 
             }
             else
             {
                  return l*Ps*( Math.min(min0, (d1+d2))  - dM); 
              }
         }
         else //open configuration
         {
             if (a2 > a1)  //divergent || ( zAMin == d1 )
             {
                 return 0.0;
             }             
             else //convergent
             {
                 return l*Ps*(d2/2)*(1 - ( (a2*a2)/(aM*a2)));
             }
         }
     }
     
     fun void updateForce()
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
         
         //find min c.p.o
         updateCPO();
         cpo1 => float min0; 
         Math.min(min0, cpo2) => min0;  
         Math.min(min0, cpo3) => min0; 
         
         forceF1(min0, Ps - inputP) => F[0];
         forceF2(min0, Ps - inputP) => F[1]; //modifying in terms of equation presented on (A.8) p.110

     }
     
     //note: is it worth implementing eq. A.5 for pressure? on p. 108 Zaccarelli
     
     //TODO: recheck this w/table - checked done!
     fun void updateCollisions()
     {           
           
         //this is what makes everything blow up... need to look at this.
         dM - cpo1 => float L1; 
         cpo3 - dM => float L2; 
         
         if( aMin <= 0) 
         {
             if( a1 <= 0 && aM > 0 ) //case [a]
             {
                 (-c1/(4*l))*a1 => I[0];
                 0 => I[1]; 
             }
             else if( a1 > 0 && aM >0 && a2 <= 0 ) //case [e]
             {
                 0 => I[0];
                 (-c2/(4*l))*a2 => I[1];
             }
             else if( a1 > 0 && aM < 0 ) //case [d]
             {
                 (-c1/(4*l))*aM => I[0]; 
                 (-c2/(4*l))*(a2 + (aM*d2)/(2*(cpo3-dM))) => I[1];
             }
             else if( a1 <= 0 && a2 <= 0 ) //case [c]
             {
                 (-c1/(4*l))*(a1 + (aM*d2)/(2*(dM-cpo1))) => I[0]; 
                 (-c2/(4*l))*(a2 + (aM*d2)/(2*(cpo3-dM))) => I[1];
             }
             else  //case [b] - a1 <=0 && aM <=0 && a2 > 0
             {
                 (-c1/(4*l))*(a1 + (aM*d2)/(2*(dM-cpo1))) => I[0];
                 (-c2/(4*l))*aM => I[1];
             }
         }
         else
         {
             0 => I[0];
             0 => I[1]; 
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
    
    //changes Ps
    fun void changePs(float ps)
    {
        ps => goalPs; 
    }
    
    fun void changePtl(float ptl)
    {
        ptl => goalPtl; 
    }
    
    fun void changePt(float pt)
    {
        pt => goalPt; 
    }
    
    /*
    fun void updatePs()
    {
        goalPs - Ps => float diff; 
        (dPs + diff)*T*modPs => dPs ; 
        Ps + dPs => Ps;      
    }
    */
    
    fun void updatePs()
    {
        updateParamD(Ps, goalPs, dPs, modPs) => dPs;
        updateParam(Ps, goalPs, dPs, modPs) => Ps;
    }
    
    fun void updatePtl()
    {
        updateParamD(Ptl, goalPtl, dPtl, modPtl) => dPtl;
        updateParam(Ptl, goalPtl, dPtl, modPtl) => Ptl;
    }
    
    fun void updatePt()
    {
        updateParamD(Pt, goalPt, dPt, modPt) => dPt;
        updateParam(Pt, goalPt, dPt, modPt) => Pt;
    }
    
    fun float updateParamD( float param, float paramGoal, float derivative, float modN )
    {
        paramGoal - param => float diff; 
        (derivative + diff)*T*modN => derivative ; 
        return derivative;   
    }

    
    fun float updateParam( float param, float paramGoal, float derivative, float modN )
    {
        param + derivative => param; 
        return param;        
    }

    fun float tick(float inP) //with trachea, inP is the input pressure from waveguide / tube / trachea modeling... 
    {
        updateX();
        updateForce(); //update the Ps with the inputP here
        updateCollisions();
        updateU(Ps - inputP); 
        updateRestingAreas();
        updateQ();
        
        //update time-varying & user-controlled parameters
        updatePs(); //implements a smoothing function
        updatePtl();
        updatePt(); 
        
        return dU; 
    }
}

//**************************
//this is redundant but I definitely know what is happening here and will stop any crazy magical thinking debug loops on this topic cold.
class Flip extends Chugen
{
    
    //the pressure up, pressure down difference
    fun float tick(float in)
    {
        return in*-1.0;   
    }  
}

//an attempt to couple vocal tract via waveguide synthesis, derived from Lous, et. al, 1998
//the Zacarelli model only includes the vibrating membrane, and uses dU as the sound output.
//dU is not the same as the pressure, so, I treat pressure reflections differently so that I can get them back into the model.
class CoupleLTMwithTract extends Chugen
{
    RingDoveSyrinxLTM lvm; //the syrinx labia
    float p1;
    
    fun float tick(float in){        
        //-- this is seconds, but I want to xlate to samples
        //does this make sense? look at parameters for airflow, too
        lvm.z0/(second/samp) * lvm.U => p1;
        
        in*2 + p1 => lvm.inputP; 
        return p1; //output pressure
    }
    
    fun float last()
    {
        return p1; 
    }
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

//Using a lumped loss scaler value for wall loss. TODO: implement more elegant filter for this, but so far, it works, so after everything else works.
class WallLossAttenuation extends Chugen
{
    7.0 => float L; //in cm --divided by 2 since it is taken at the end of each delay, instead of at the end of the waveguide
    34740 => float c; // in m/s
    c/(2*L) => float freq;
    wFromFreq(freq) => float w;   
    //150.0*2.0*pi => float w;  
    
    0.3 => float a; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
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

//************************** Main Code, not classes.
//**************************

//sound of syrinx membrane through vocal tract
//run it through the throat, etc.
BirdTracheaFilter lp, lp2; 
WallLossAttenuation wa, wa2;
HPFilter hpOut;
Flip flip, flip2;
DelayA delay, tracheaForward;
DelayA delay2, tracheaBack; 

//audio out
RingDoveSyrinxLTM ltm => delay => lp => blackhole;
lp => wa => delay => LPF lpf => Dyno limiter => dac;
//1 => lpf.Q;
700 => lpf.freq; //arbitrary, by ear after testing. 

//**************************
//**************************

//couple the returning pressure reflection to the syrinx model
CoupleLTMwithTract coupler; //this waveguide is for pressure reflection for interaction with larynx, does not have an audio out.
coupler => tracheaForward => lp2 => tracheaBack => wa2 => blackhole; //took out flip for closed mouth
ltm @=> coupler.lvm;

//the feedback from trachea reflection, affecting pressure in syrinx membrane dynamics
Gain p1; 
wa2 => p1; 
wa2 => tracheaForward => blackhole;  
p1 =>  coupler => blackhole; //the reflection also is considered in the pressure output of the syrinx
  

//limit output from trachea, just in case things get out of control.
limiter.limit();

dac => WvOut2 writer => blackhole; //record to file
writer.wavFilename("/tmp/testDoveSounds.wav");
// temporary workaround to automatically close file on remove-shred -- is it temporary??
null @=> writer;

11.0 => float L;  //in centimenters, from here: https://www.researchgate.net/publication/308389527_On_the_Morphological_Description_of_Tracheal_and_Esophageal_Displacement_and_Its_Phylogenetic_Distribution_in_Avialae/download?_tp=eyJjb250ZXh0Ijp7ImZpcnN0UGFnZSI6Il9kaXJlY3QiLCJwYWdlIjoiX2RpcmVjdCJ9fQ
//8 - trachea, 3 - head - included 3 cm extra for head, not modeling that separately. maybe later.
                  
ltm.a => float a; //from small bird measurements in Smyth
ltm.a => float h; 
L => wa.L;
a => wa.a;
L => wa2.L;
a => wa2.a;
wa.calcConstants();
wa2.calcConstants();
setParamsForReflectionFilter(lp);
setParamsForReflectionFilter(lp2);


//347.4 => float c; // in m/s
c/(2*(L/100.0)) => float LFreq; //speed of sound - c - is in meters, so convert L to meters here.

//I didn't *2 the frequency since there is no flip - 3/1/2024
( (second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
//( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm

period::samp => delay.delay;
//period::samp => delay2.delay; 



/*
FileIO fout;

// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/testEnv.txt", FileIO.WRITE );
string output;
*/

//while( now < later)
//{
    //Ps
   
//    0.0125 => ltm.Ps;
//    20-1000*envPs.value() => ltm.Ptl;
//    1 - envPs.value() => ltm.Pt;

//    envPs.update(); 
//    envPs.value() + "\n" => output; 
//    fout.write( output ); 
   
//    1::samp => now; 
//}



mouseEventLoopControllingAirPressure();

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
    
    -10 => float audioMax;
    10 => float audioMin;
    
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
                
                //<<< ltm.inputP, coupler.last(), ltm.Ps, ltm.U, ltm.z0, ltm.dU >>>; 
                
                // get the normalized X-Y screen cursor pofaition
                // <<< "mouse normalized position --",
                // "x:", msg.scaledCursorX, "y:", msg.scaledCursorY >>>;
                Math.sqrt(msg.deltaY*msg.deltaY + msg.deltaX*msg.deltaX) => float val;
                // Math.max(max, val) => max; 
                val / 42 => float totVal; 

                logScale( msg.scaledCursorX, 0.000000001, 1.0 ) => float scaledX; 
                logScale( msg.scaledCursorY, 0.000000001, 1.0 ) => float scaledY;
                
               //msg.scaledCursorX * 0.006 => ltm.Ps;
                //msg.scaledCursorX * 0.01 => ltm.Ps;
                
                ltm.changePs((msg.scaledCursorX)*0.036 + 0.001); //go up to 0.0692
          

               //msg.scaledCursorX * (0.01225-0.007954) + 0.007954 => ltm.Ps;
               
               msg.scaledCursorY * 15 + 5 => float Ptl;
               ltm.changePtl(Ptl);
               
               
              
               
               //if( Ptl > 19.5 )
               
               
               //((1.0-msg.scaledCursorY)*1.5)  - 1.0 => ltm.Pt;
               ltm.changePt(((1.0-msg.scaledCursorY)*2)  - 1.0);

               //<<<ltm.Ps>>>;
               
                //msg.scaledCursorX * (0.01225-0.010954) + 0.010954 => ltm.Ps;
                //msg.scaledCursorX * (0.001225/2-0.000954) + 0.000954 => ltm.Ps;
                //0.008 works
                //0.1 - 13.5 ptl - highest
                //0.1224 - 18 ptl lowest w/o distortion
                //0.11
                
                //0.01222 => ltm.Ps;

               //(msg.scaledCursorY*1.5)  - 1.0 => ltm.Pt;
               //(1.0- msg.scaledCursorY) * 20.0 => ltm.Ptl;
               
               Math.max(audioMax, limiter.last()) => audioMax; 
               Math.min(audioMin, limiter.last()) => audioMin; 
 
               
               <<<ltm.Ps+"," + ltm.Ptl+ "," + ltm.Pt + "," + limiter.last() + " ," +audioMin + "," + audioMax >>>;

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



function void setParamsForReflectionFilter(BirdTracheaFilter lp)
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
    //0.5  => float ka; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
    
    //expected results -- eg. the wT frequency equation as given does not match the example 4.13(?), but the standard cutoff for metal waveguides does fine 
    //need to triple-check calculations, perhaps send an email to her.
    ka*(c/ltm.a)*ltm.T => float wT; //transition frequency wT
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
    //for the low-pass reflector
    a1 => lp.a1;
    b0 => lp.b0; 
    
    //for the highpass output, from Smyth, again
    a1 => hpOut.a1; 
    b0 => hpOut.b0; 
    
    <<<"a:"+a>>>;
    <<<"oT:" + oT + " wT:" + wT>>>;
    <<<"a1:"+a1 + "   b0:"+b0>>>;
    
    <<<"*************">>>;
    
    
    
    //<<< "wT: " + wT + " oT: " + oT + " a1: "+ a1 + " b0: " + b0 >>>;
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

/*
<<< "**********************************" >>>;

FileIO fout;

// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/out3.txt", FileIO.WRITE );

// test

if( !fout.good() )
{
    cherr <= "can't open file for writing..." <= IO.newline();
    me.exit();
}


    "x[0]"  + "," + "x[1]" +"," + "dx[0]"  + "," + "dx[1]" + "," + "a1" + "," + "a2" + "," + "dU"  + ", "+"F[0]" + "," + "F[1]" + "," + "I[0]" + "," + "I[1]" +"\n" => string output; 
    fout.write( output );



now => time start;
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
    
    //<<< ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.F[0] + "," + ltm.F[1] + ","+ ltm.I[0] + "," + ltm.I[1] + "\n" >>>;
    fout.write( output ); 
    
    
    fout.write( output ); 

    1::samp => now;   
}  


// close the thing
fout.close();


//TODO for tomorrow:
//1. Check expectations, this is close -- but I only skimmed that part
//2. recheck collision equations --> check
//3. recheck parameters and initial conditions --> check
//4. recheck forces agains --> check

*/


