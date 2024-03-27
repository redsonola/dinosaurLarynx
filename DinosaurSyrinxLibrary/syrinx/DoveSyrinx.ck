//*************
//Coder: Courtney Brown
//Feb 2023 - Mar.,  2024
//An interactive model of a dove syrinx + vocal tract. For eventual use in hadrosaur skull musical instruments. 
//See comments for the ElemansZaccarelliDoveSyrinx for citations and details.
//*************
public class DoveSyrinx extends Chugraph
{
     ElemansZaccarelliDoveSyrinx membrane; //this goes to dac
     CoupleLVMwithTract coupler; //this waveguide is for pressure reflection for interaction with larynx, does not have an audio out.
     BirdTracheaFilter lp, lp2; 
     WallLossAttenuation wa, wa2;
     HPFilter hpOut;
     Gain flip, flip2; //just to scale by -1
     DelayA delay, tracheaForward; //delays for pressure reflection
     DelayA delay2, tracheaBack; //delays for pressure reflection
     Gain p1; //reflected pressure
     float a; //membrane width
     float h; //membrane height - depreciated
     float L; //full trachea length to mouth
     Dyno limiter;
     LPF lpf; //low-pass filter, for closed mouth
     
     0 => int whichDinosaur;
     1 => int corythosaurus;
     0 => int dove;
    
    function void init()
    {
        -1 => flip.gain;
        -1 => flip2.gain;
        
        
        //**SOUND of syrinx membrane through vocal tract
        //run it through the throat, etc. for the audio out
        membrane => delay => lp => blackhole;
        lp => wa => delay => lpf => limiter => outlet;
        700 => lpf.freq; //arbitrary, by ear after testing. 
    
        //limit output from trachea, just in case things get out of control.
        limiter.limit();
        
        //**COUPLING and modeling the returning pressure reflection to the syrinx model
        coupler => tracheaForward => lp2 => tracheaBack => wa2 => blackhole; //took out flip for closed mouth
        membrane @=> coupler.lvm;
    
        //the feedback from trachea reflection, affecting pressure in syrinx membrane dynamics
        wa2 => p1; 
        wa2 => tracheaForward => blackhole;  
        p1 =>  coupler => blackhole; //the reflection also is considered in the pressure output of the syrinx, unlike Fletcher/Smyth, I don't add at this step but use the Lous, et. al. (1998) equation to combine inside the plug-in
    
        //** Setting filter parameters
        11.0 => L
        ;  //in centimenters, from here: https://www.researchgate.net/publication/308389527_On_the_Morphological_Description_of_Tracheal_and_Esophageal_Displacement_and_Its_Phylogenetic_Distribution_in_Avialae/download?_tp=eyJjb250ZXh0Ijp7ImZpcnN0UGFnZSI6Il9kaXJlY3QiLCJwYWdlIjoiX2RpcmVjdCJ9fQ
        //8 - trachea, 3 - head - included 3 cm extra for head, not modeling that separately. maybe later.
    
        //set all the initial parameters for filters, etfc.
        membrane.a => a;
        membrane.a => h; 
        L => wa.L;
        a => wa.a;
        L => wa2.L;
        a => wa2.a;
        wa.calcConstants();
        wa2.calcConstants();
        setParamsForReflectionFilter(lp);
        setParamsForReflectionFilter(lp2);
    
        //347.4 => float c; // in m/s
        membrane.c/(2*(L/100.0)) => float LFreq; //speed of sound - c - is in meters, so convert L to meters here.
    
        //I didn't *2 the frequency since there is no flip - 3/1/2024
        ( (second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
        //( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
    
        period::samp => delay.delay; //for sound
        period::samp => tracheaForward.delay; //reflection back into the model
        period::samp => tracheaBack.delay; ///for reflection back into the model 
    
        //**END Setting filter parameters
    }
    
    //********************************************************************************************************
    //************END MAIN INIT
    //********************************************************************************************************
    
    
    //********************************************************************************************************
    //************Some Functions to set filter parameters as well as the event loop
    //********************************************************************************************************
    
    //0-1 -- input pressure to control via other ways than mouse
    function updateInputPressure(float inPs)
    {
        if(whichDinosaur == dove)
        {
            //input air pressure changes based on x screen position
            //Ranges determined by Zaccarelli(2009) p. 73, Fig. 4.3, lower end increased for mouse playability 
            membrane.changePs(inPs*0.037 + 0.001); //go up to 0.0692
        }
        else
        {
            membrane.changePs(inPs*0.05);     
        }
    }
    
    //0-1 -- input to control via other ways via other ways than mouse
    function updateInputMusclePressure(float inPressure)
    {
        if(whichDinosaur == dove)
        {
            //Ranges from same set of figures on p. 73 illustrating muscle pressures for coo sound
            inPressure * 15 + 5 => float Ptl;
            membrane.changePtl(Ptl); 
            membrane.changePt(((1.0-inPressure)*2)  - 1.0);
        }
        else
        {
            inPressure * 40 => float Ptl;
            membrane.changePtl(Ptl);
            membrane.changePt((((1.0-inPressure)*2)  - 1.0)*2.0); //Pt is generally inverse of Ptl during dove calls -- well to the limited extent of the paper
        }
    } 
    
    //mouse event loop controlling air pressure & muscle pressure
    function void runWithMouse()
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
                    if(whichDinosaur == dove)
                    {
                        //input air pressure changes based on x screen position
                        //Ranges determined by Zaccarelli(2009) p. 73, Fig. 4.3, lower end increased for mouse playability 
                        membrane.changePs((msg.scaledCursorX)*0.037 + 0.001); //go up to 0.0692
                    
                        //Ranges from same set of figures on p. 73 illustrating muscle pressures for coo sound
                        msg.scaledCursorY * 15 + 5 => float Ptl;
                        membrane.changePtl(Ptl);
                        membrane.changePt(((1.0-msg.scaledCursorY)*2)  - 1.0);
                    }
                    else
                    {
                        //input air pressure changes based on x screen position
                        //Ranges determined by other vocal pressures -- so far this does not seem to change much
                        //need to do more research. Higher pressures lead to instabilities tho anyways, so if 
                        //higher pressures are used, then likely other params (eg. stiffness, etc.) need to change
                        membrane.changePs((msg.scaledCursorX)*0.05 + 0.001); //go up to 0.0692
                        
                        msg.scaledCursorY * 40 => float Ptl;
                        membrane.changePtl(Ptl);
                        membrane.changePt((((1.0-msg.scaledCursorY)*2)  - 1.0)*2.0);
                        
                        //incase of blow up
                        if( membrane.inputP > 3.0 )
                        {
                            delay.clear();
                            delay2.clear();
                            tracheaForward.clear();
                            tracheaBack.clear();                   
                            membrane.reset();                   
                        }                       
                    }
                }
                
            }  
            1::samp => now;
        }  
        
    }
    
    
    //scale input values logarithmically
    function float logScale(float in, float min, float max)
    {
        Math.log( max / min ) / (max - min)  => float b;
        max / Math.exp(b*max) => float a;
        return a * Math.exp ( b*in );
    }
    
    
    
    //create low-pass filter for the waveguide synthesis, mostly implemeted from Smyth (2004)
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
        1.8412  => float ka; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
        //0.5  => float ka; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
        
        //expected results -- eg. the wT frequency equation as given does not match the example 4.13(?), but the standard cutoff for metal waveguides does fine 
        //need to triple-check calculations, perhaps send an email to her.
        ka*(membrane.c/membrane.a)*membrane.T => float wT; //transition frequency wT
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
        
    }   
    


    function void makeCorythosaurus()
    {
        corythosaurus => whichDinosaur;
        
        //difference in scale btw dove and dinosaur 
        4.5/0.15 => float dinoScale; //based on trachea width


        //********* constants that change during modeling the coo!!! 2/2024 Table C.1 p. 134 ************ NOW CORYTHOSAURUS - 3/2024 *************
        0.0017 * dinoScale =>  membrane.m; //mass, table C.1
        0.022 => membrane.k; //stiffness -- orig. 0.02 in fig. 3.2 zaccharelli -- now back to original-ish? table C.1
        0.006 => membrane.kc; //coupling constant, table C.1 (before, 0.005)
        0.1 * Math.sqrt(membrane.m*membrane.k)  => membrane.r; //damping, table C.1 // 0.0012 => float r; --> moved it back to human, previously 0.001 for dove
    
    //biological parameters of ring dove syrinx, in cm -- ***change during coo! Table 4.1, p76
    
    //ALLIGATORS
    //https://cob.silverchair-cdn.com/cob/content_public/journal/jeb/214/18/10.1242_jeb.051110/3/3082.pdf?Expires=1713477414&Signature=ZRQGYrOxeB9ylwkicgM~-H5G~wPwGVuW8fAnptV4JBdqWiercZWPmTVWFxPmGD~EAt-GG6S4UYN7NdoozOv51hdAO9e4mL6SmiXGoWi3hxlImvWm9psd~NCqliAGftDIn~o9tHncPuiyCbixzDYiQZx0-iiAGlF0AG2d~gLL0nI7DS6i7ZV6qVopaEqnQHNfNDVkutzz4lZvr~8vPeNYT0TN8MDZ8Fm8oohlLtkKwRaWWr3ZLNLYA5AKQJNMLbirENTlsGsB4xJzWQyUYigSRZzkEAQFnSb304m8WrLSLJsB-wJyFSJk7bvkMdCEc-3KdhACupRMNK4qkvoP~pdfvg__&Key-Pair-Id=APKAIE5G5CRDK6RD3PGA
    //m1=0.125 g, m2=0.025 g,
    //k1=80,000 g s^-2, k2=8000 g s^-2, kc=25,000g s^2, r = 
    //in model units: k1 = 0.08, k2 = 0.008, kc = 0.025
    
    //c1=3k1, c2=3k2 --> same values as here, except for asymmetrical model
    
    //d1 = 0.25cm, d2=0.05cm, l=1.4cm and while the
    //damping constants were set as r= 2cpo(mi*ki)^1/2, cpo = 0.05
    //r1 = 2*0.05* (m1*k1)^1/2 = 0.1*
    
//ALLIGATOR PAPER
//Vocal fold length is positively correlated with body mass (Fig.3).
//A scaling factor of 0.35 (r2= 0.98; Fig.3), suggests that vocal fold
//length scales with body size almost with geometric similarity.
//they used alligators 31-37cm in length, 0.9 and 1.4kg body mass
    
        4.5 => membrane.w;//1/2 trachea width -- Corythosaurus
        2*membrane.w => membrane.a;//full trachea width
        21.6 => membrane.l; //length of the trachea, 4.1 table, 0.32 **changed, 8.9-14in. med. 11.45", 31-37" (nose to end of body, not tail) alligator is 1.2cm, 3-4x that of a dove, 18x that for Corythosaurus (est. 6m nose to end of body not tail)?? 24-32.4
    
        //some wild speculation
        0.003 * 18 => membrane.a01; //lower rest area
        0.003 * 17 => membrane.a02; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx

        //heights -- alligator was not much changed from dove (although one is syrinx & one is larynx, hard to measure) humans were less than 2x alligator although much bigger, dunno
        //it does not seem like these heights scale up a lot with size
        //I need to do more research. I've chosen a really conservative number
        0.04 * 3 => membrane.d1; //1st mass height -- alligator is: d1=0.25, d2=0.05cm -- perhaps this actually doesn't scale up that much? leave alone for now.
        (0.24 - membrane.d1)* 3  => membrane.d2; //2nd mass displacement from first
        (0.28 - (membrane.d1+membrane.d2))* 3  => membrane.d3; //3rd mass displacement from 2nd
            
        //double that of dove but?
        40.0 => membrane.maxPtl; 
    
        //more time-varying parameters -- vary with different muscle tension values
        -0.03 * dinoScale => membrane.a0min; 
        0.01 * dinoScale => membrane.a0max; 
        membrane.a0max - membrane.a0min => membrane.a0Change; 
    
        //time-varying (input control) parameters Q, which reflect sum of syringeal pressures & resulting quality factor impacting oscillation eq. in updateX()
        0.5 => membrane.Qmin; //0.8 for dove
        3 => membrane.Qmax; //1.2 for dove
        membrane.Qmin => membrane.Q; //F(t) = Q(t)F0
        -0.3 => membrane.Pt; //-1 to 0.5 using CTAS, normalized to 1, max but usually around 0.5 max -- from graph on p. 70, Pt = PICAS - PCTAS (max 3.5), 
        membrane.Pt + membrane.Ptl => membrane.Psum;
        0.0 => membrane.minPsum; 
        40.0 => membrane.maxPsum;  
        membrane.Qmax - membrane.Qmin =>  membrane.Qchange;
    
        //area of opening of syrinx at rest -- need to re-calculate
        2.0*membrane.l*membrane.w => membrane.a0; //a0 is the same for both masses since a01 == a02

        //recalc geometry
        membrane.d1 + (membrane.d2/2) => membrane.dM; //imaginary horizontal midline -- above act on upper mass, below on lower

         //***adding the input pressure to the force -- 2/29/2024
        //**********from the Fletcher model, adding back vocal tract effects
        0 => membrane.inputP; //this is reflection from vocal tract
        (membrane.p*membrane.c*100)/(pi*membrane.a*membrane.a) => membrane.z0; //impedence of brochus --small compared to trachea, trying this dummy value until more info 
        membrane.z0/6   => membrane.zG; //NOT USED erase --> an arbitrary impedance smaller than z0, Fletcher
        0.0 => membrane.pAC; //reflected pressure from the vocal tract after coupling - incl. impedence, etc.

        //Steineke & Herzel, 1994  --this part was not clear there but--->
        //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
        //https://doi.org/10.1063/1.166078
        //confirmed in Herzel & Steineke 1995 Bifurcations in an asymmetric vocal-fold model
        //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality
        3.0 * membrane.k => membrane.c1; 
        3.0 * membrane.k => membrane.c2;       
        
        //reinit -- this needs to be refactored
        116 => L;
        membrane.a => a;
        membrane.a => h; 
        L => wa.L;
        a => wa.a;
        L => wa2.L;
        a => wa2.a;
        wa.calcConstants();
        wa2.calcConstants();
        setParamsForReflectionFilter(lp);
        setParamsForReflectionFilter(lp2);
        
        //347.4 => float c; // in m/s 
        membrane.c/(2*(L/100.0)) => float LFreq; //speed of sound - c - is in meters, so convert L (in cm) to meters here.
    
        //I didn't *2 the frequency since there is no flip - 3/1/2024
        ( (second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
        //( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
    
        period::samp => delay.delay; //for sound
        period::samp => tracheaForward.delay; //reflection back into the model
        period::samp => tracheaBack.delay; ///for reflection back into the model 
        
        10 => lpf.Q;
        200 => lpf.freq; //arbitrary, by ear after testing. 

    }


}