Machine.add("/Users/courtney/Programs/physically_based_modeling_synthesis/bird_vocalizations_feb2023/Elemans_versions/ElemansModel_NonSongbird.v6_add_params_makeClosedMouth_asLibrary.ck") => float id; 

dac => WvOut2 writer => blackhole; //record to file
writer.wavFilename("/tmp/testDoveSounds.wav");
// temporary workaround to automatically close file on remove-shred -- is it temporary??
null @=> writer;

//0.15 => float w; //trachea width
//0.32 => float l; //length of the trachea, 4.1 table **changed

8.0 => float L;  //in centimenters, from here: https://www.researchgate.net/publication/308389527_On_the_Morphological_Description_of_Tracheal_and_Esophageal_Displacement_and_Its_Phylogenetic_Distribution_in_Avialae/download?_tp=eyJjb250ZXh0Ijp7ImZpcnN0UGFnZSI6Il9kaXJlY3QiLCJwYWdlIjoiX2RpcmVjdCJ9fQ
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
c/(2*(L/100.0)) => float LFreq; // -- the resonant freq. of the tube (?? need to look at this)

//I didn't *2 the frequency since there is no flip - 3/1/2024
( (second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm
//( (second / samp) / (2*LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm

period::samp => delay.delay;
//period::samp => delay2.delay; 

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
