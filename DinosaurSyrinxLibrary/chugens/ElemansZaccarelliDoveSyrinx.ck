    //*************
//Coder: Courtney Brown
//Feb 2023 - Mar.,  2024
//An interactive model of a dove syrinx + vocal tract. For **eventual** use in hadrosaur skull musical instruments.
    
    //Model derived from: 
    //1. https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=6a2f5db63fa313965386c88dc6e3a71b19fd5f2e#page=25
    //2. https://findresearcher.sdu.dk/ws/portalfiles/portal/50551636/2006_Zaccarelli_etal_ActaAcustica.pdf
    //3. https://hal.science/hal-02000963/document -- previous model that this is based on
    //4. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2607454/#bib46 (the elemans paper -- other 2 are references to complete the model)
    
    //a good perspective of the state of bird vocal modeling in.... 2002
    //https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=dbca9e2ef474525b4b9417ec92daf0ae88191a97
    
    //implementation of Ishizaka & Flanagan's 2 mass vocal model, for reference
    //https://gist.github.com/kinoh/5940180
    
    //check reference list
    //biorxiv.org/content/biorxiv/early/2019/10/02/790857.full.pdf
    
    //found the dissertation with all the equations:
    //https://edoc.hu-berlin.de/bitstream/handle/18452/17159/zaccarelli.pdf?sequence=1
    
    //2010 paper on the oscine bird
    //http://www.lsd.df.uba.ar/papers/PhysRevE_comp_model.pdf
    
    //	D. N. During and C. P. H. Elemans. Embodied Motor Control of Avian Vocal Production. In Vertebrate Sound Production and Acoustic Communication. Springer International Publishing, 119?157, 2016. https://doi.org/10.1007/978-3-319-27721-9_5
    
    //Nonlinear dynamics in the study of birdsong
    //https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5605333/
    
public class ElemansZaccarelliDoveSyrinx extends Chugen
{
    347.4 => float c; //speed of sound
    
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
    
    [0.0, 0.0] @=> float I[]; //collision forces between 2 side of syrinx membrane
        
    //time-varying (control) tension parameters (introduced in ch 4 & appendix C)
    19.0 => float Ptl; //stress due to the TL tracheolateralis (TL) - TL directly affects position in the LTM -- probably change in dinosaur.
    0.0 => float minPtl; 
    20.0 => float maxPtl; 
    
    //changing Ptl
    Ptl => float goalPtl;//the tension to increase or decrease to    
    0.0 => float dPtl; //change in tension per sample -- only a class variable so can check value. 
    5.0 => float modPtl; //a modifier for how quickly dx gets added
    
    //more time-varying parameters -- vary with different muscle tension values
    -0.03 => float a0min; 
    0.01 => float a0max; 
    a0max - a0min => float a0Change; 
    
    //time-varying (input control) parameters Q, which reflect sum of syringeal pressures & resulting quality factor impacting oscillation eq. in updateX()
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

    //area of opening of syrinx at rest
    2.0*l*w => float a0; //a0 is the same for both masses since a01 == a02

    //Ps -- the input air pressure below syrinx
    //pressure values - limit cycle is half of predicted? --> 0.00212.5 to .002675?
    //no - 0.0017 to 0.0031 -- tho, 31 starts with noise, if dividing by 2 in the timestep
    0.0045 => float Ps; //pressure in the syringeal lumen, 

    //changing Ps -- the input air pressure below syrinx
    Ps => float goalPs;//the tension to increase or decrease to    
    0.0 => float dPs; //change in tension per sample -- only a class variable so can check value. 
    50.0 => float modPs; //a modifier for how quickly dx gets added

    //0.004 is default Ps for this model but only 1/2 of predicted works in trapezoidal model for default params (?)
    //0.02 is the parameter for fig. C3 & does produce sound with the new time-varying tension/muscle pressure params

    //geometry
    d1 + (d2/2) => float dM; //imaginary horizontal midline -- above act on upper mass, below on lower

    //geometries (ie, areas) found in order to calculate syrinx opening and closing forces
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

    //measures of air flow. dU is the audio out    
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
    //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality
    3.0 * k => float c1; 
    3.0 * k => float c2; 

    //update the air flow in the syrinx membrane, ie, the U
    //dU, 1st derivative of U, is used as the audio output variable
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

    //update the x[], dx[], d2xp[values] - the values describing how open (length-wise) each point (ie, mass) of the syrinx is
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
//NOT using -- 1/4/2024
/*
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
*/

    //heaveside function as described in Zaccarelli(2009)
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


    //update the points at which collisions begin
    fun void updateCPO()
    {
        //find all the CPOs
        (a0*d1)/(a0-a1) =>  cpo1; 
    
        d1 - ( (a1*d2)/(a2-a1) ) =>  cpo2; 
    
        d1 + d2 - ( (a2*d3)/(a0-a2) ) =>  cpo3;  
    
    }

    //finds force 1 - F[0] 
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

    //finds force 1 - F[1] 
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

    //update the force for the oscillation equation in updateX()
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

    //Calculate the forces for any vocal fold collisions (I[]), if any
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


    //update syringeal membrane areas due to syringeal & TL pressure (implements Zaccharelli, 2008 Ch. 4 & Appendix C)
    fun void updateRestingAreas()
    {
        Ptl*(a0Change/maxPtl) + a0min => a01; 
        Ptl*(a0Change/maxPtl) + a0min => a02; 
    }

    //update the Q based on muscle tension. Q (quality factor) models ratio of energy stored to energy dissapated in a system, in this context combines the muscle pressure
    //& then modifies stiffness & mass values in the oscillation equation in updateX()
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

    //******a set of functions to change the user-controlled time-varying parameters. 
    //*****These are set to smooth the change over time, to prevent cracks and breaks in the sound
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


    //Main processing function of the chugen (plug-in). Everything that does stuff is called from here
    function float tick(float inP) //with trachea, inP is the input pressure from waveguide / tube / trachea modeling... 
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
    
