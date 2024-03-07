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
     Flip flip, flip2; //just to scale by -1
     DelayA delay, tracheaForward; //delays for pressure reflection
     DelayA delay2, tracheaBack; //delays for pressure reflection
     Gain p1; //reflected pressure
     float a; //membrane width
     float h; //membrane height - depreciated
     float L; //full trachea length to mouth
     Dyno limiter;
     LPF lpf; //low-pass filter, for closed mouth
    
    function void init()
    {
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
        //input air pressure changes based on x screen position
        //Ranges determined by Zaccarelli(2009) p. 73, Fig. 4.3, lower end increased for mouse playability 
        membrane.changePs(inPs*0.037 + 0.001); //go up to 0.0692
    }
    
    //0-1 -- input to control via other ways via other ways than mouse
    function updateInputMusclePressure(float inPressure)
    {
        //Ranges from same set of figures on p. 73 illustrating muscle pressures for coo sound
        inPressure * 15 + 5 => float Ptl;
        membrane.changePtl(Ptl); 
        membrane.changePt(((1.0-inPressure)*2)  - 1.0);
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
        
        0 => int whichBird; //will use in future
        
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
                    // get the normalized X-Y screen cursor 
                    // <<< "mouse normalized position --",
                    // "x:", msg.scaledCursorX, "y:", msg.scaledCursorY >>>;
                    Math.sqrt(msg.deltaY*msg.deltaY + msg.deltaX*msg.deltaX) => float val;
                    val / 42 => float totVal; 
                    
                    //create a version in logarithmic scale, could be useful, but not so far
                    logScale( msg.scaledCursorX, 0.000000001, 1.0 ) => float scaledX; 
                    logScale( msg.scaledCursorY, 0.000000001, 1.0 ) => float scaledY;
                    
                    //input air pressure changes based on x screen position
                    //Ranges determined by Zaccarelli(2009) p. 73, Fig. 4.3, lower end increased for mouse playability 
                    membrane.changePs((msg.scaledCursorX)*0.037 + 0.001); //go up to 0.0692
                    
                    //Ranges from same set of figures on p. 73 illustrating muscle pressures for coo sound
                    msg.scaledCursorY * 15 + 5 => float Ptl;
                    membrane.changePtl(Ptl);
                    membrane.changePt(((1.0-msg.scaledCursorY)*2)  - 1.0);
                    
                    //Just some useful code for caw.
                    Math.max(audioMax, limiter.last()) => audioMax; 
                    Math.min(audioMin, limiter.last()) => audioMin; 
                    
                    //<<<ltm.Ps+"," + ltm.Ptl+ "," + ltm.Pt + "," + limiter.last() + " ," +audioMin + "," + audioMax >>>;
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
    




}