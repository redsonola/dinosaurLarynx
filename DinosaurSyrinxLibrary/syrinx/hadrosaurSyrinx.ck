//*************
//Coder: Courtney Brown
//Feb 2023 - Mar.,  2024
//An interactive model of a hadrosaur syrinx + vocal tract. For use in hadrosaur skull musical instruments.

//--The following code is based on:
//-- https://www.phys.unsw.edu.au/music/people/publications/Fletcher1988.pdf

//-- And the implementation is strongly informed by:
//-- Tamara Smyth, Applications of Bioacoustics to Musical Instrument Technology, Ph.D. thesis, Stanford University, April 2004. PDF
//-- Tamara Smyth and Julius O. Smith, The sounds of the avian syrinx---are they really flute-like?, in DAFX 2002 Proceedings, Hamburg, Germany, September 2002, International Conference on Digital Audio Effects, pp. 199--202. PDF

//Notes: updated songbird model from Fletcher
//https://www.phys.unsw.edu.au/music/people/publications/Fletcher1993.pdf Fletcher1992
//https://www.phys.unsw.edu.au/music/people/publications/Fletcheretal2006.pdf //songbird
//https://www.phys.unsw.edu.au/music/people/publications/Fletcheretal2004.pdf //dove

//Parameters are adjusted to reflected Corythosaurus measurements. The measurement of the trachea length was estimated by Thomas Dudgeon using a specimen in the ROM
//The membrane & trachea width was estimated by Courtney Brown using specimens from Tyrell (Hyoid and Skull opening) as well as ROM 1933 (these are informed speculations)
//Other parameters specific to the Corythosaurus are estimated/speculated by Courtney Brown using ratios and diagrams from bird anatomy

//Corythosaurus sizes
//https://www.proquest.com/citedreferences/MSTAR_2440425772/4C70A2332F914DFCPQ/1?accountid=6667
//& downloaded --> see

//*************
public class HadrosaurSyrinx extends Chugraph
{
        EnvelopeFollower follower; //mic in
        OnePole envF_breath;
        LPF breath_env_lp; 
        
        //set global trachea parameter
        4.5 => float a;
        116.0 => float L;
        4.5 => float h;
        0.0 => float period;
        0.05 => float d; 
        
        SyrinxMembrane mem;
        SyrinxMembrane mem2;
        DelayA delay;
        DelayA delayMem2;
        DelayA tracheaOut;
        BirdTracheaFilter loop;
        Flip flip;
        DelayA tracheaBack;
        
        Dyno limiter;
        HPFilter hpOut;
        
        DelayA bronch1Back, bronch2Back;
        WallLossAttenuation waBronchBack, waBronch2Back;
        Gain adder2;
        ScatteringJunction junction; 
        
        Gain p1; //returning sound reflection pressure in syrinx model
        
        function void init()
        {
            
            //the envelope follower for the breath
            follower.envelopeFollower() @=> envF_breath => breath_env_lp => blackhole;
            100 => breath_env_lp.freq;
            1 => breath_env_lp.Q;
            
            mem => delay; 
            mem2 => delayMem2;
            
            //I didn't *2 the frequency since there is no flip - 3/1/2024
            mem.c/(2*(L/100.0)) => float LFreq; //speed of sound - c - is in meters, so convert L to meters here.
            ( (second / samp) / (LFreq) - 1) => float period; //* 0.5 in the STK for the clarinet model... clarinet.cpp hmmm

            period::samp => delay.delay;
            period::samp => delayMem2.delay;
            
            //from the scattering junction out to the mouth
            //DelayA tracheaOut => WallLossAttenuation tracheaWA => BirdTracheaFilter loop => blackhole;
            tracheaOut => loop => blackhole;
            period::samp => tracheaOut.delay;
            
            //reflection back to scattering junction
            loop  => flip => tracheaBack;
            period::samp => tracheaBack.delay;
            
            //from trachea to sound out the 'mouth'
            tracheaOut => hpOut => limiter => outlet; //from trachea to sound out -- changed from dac to outlet
            limiter.limit();
            //10 => limiter.gain; //make it louder
            
            //reflection from scattering junction back to bronchus beginning -- 1st bronchus
            bronch1Back => waBronchBack;// => delay; 
            waBronchBack => p1; 
            mem => p1; //try prev. way
            p1 => mem; 
            p1 => delay; 
            
            period::samp => bronch1Back.delay;
            
            //reflection from scattering junction back to bronchus beginning -- 2nd bronchus
            bronch2Back => waBronch2Back; // => delayMem2; //reflection from trachea end back to bronchus beginning
            waBronch2Back => adder2; 
            mem2 => adder2; //try prev. way
            adder2 => mem2; 
            adder2 => delayMem2;
            period::samp => bronch2Back.delay;
            
            //Aaaand -- setup the scattering junction here to connect all the passage ways
            junction.scatter( delay, delayMem2, tracheaBack, bronch1Back, bronch2Back, tracheaOut, mem.z0);
            
            //initialize the global variables for a particular bird type
            initGlobals();
            
            setParamsForReflectionFilter(); //approximating from Smyth diss. 
            hadrosaur(); //init for hadrosaur parameters
            
    }
        
    //--2/21 1p fixed reflection filter
    function void setParamsForReflectionFilter()
    {
        //https://asa-scitation-org.proxy.libraries.smu.edu/doi/pdf/10.1121/1.1911130
        //Benade -- acoustics in a cylindrical tube reference for w & ka
        
        //0.5 => ka; //estimation of ka at cut-off from Smyth - NOPE.
        //find cutoff freq from this reference, then find ka
        //https://www.everythingrf.com/community/waveguide-cutoff-frequency#:~:text=Editorial%20Team%20%2D%20everything%20RF&text=The%20cut%2Doff%20frequency%20of%20a%20waveguide%20is%20the%20frequency,this%20frequency%20will%20be%20attenuated.
        //ka at the cut-off frequency of the waveguide
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
         1000.0 => mem.modT; 
         100 => mem.modPG; //was 100
         1000.0 => mem2.modT; 
         100 => mem2.modPG; 
         
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
         ( (0.5*second / samp) / (LFreq) - 1) => period; 
         
         period::samp => delay.delay;
         period::samp => delayMem2.delay;
         period::samp => tracheaOut.delay;
         period::samp => tracheaBack.delay;
         period::samp => bronch2Back.delay;
         period::samp => bronch1Back.delay;
         
         setParamsForReflectionFilter(); 
     }
     
     //0-1 -- input pressure to control via other ways than mouse
     function updateInputPressure(float inPG)
     {
         float pG1; 
         inPG * 300000 => pG1;
         //ctrlValue * 250000 => pG1;
         Math.min(pG1, 300000) => pG1;
         mem.changePG(pG1); 
         mem2.changePG(pG1);         
     }
     
     //0-1 -- input to control via other ways via other ways than mouse
     function updateInputTension(float inTension)
     {
         mem.initT*0.5 + inTension*mem.initT*5.0 => float t;
         mem.changeTension(t);
         mem2.changeTension(t);         
     } 
     
     //mouse event loop controlling air pressure
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
         
         0 => int whichBird; 
         
         // infinite event loop
         0 => float max1; 
         while( true )
         { 
             1::ms => now; 
             envF_breath.last() => float ctrlValue;
             
             float pG1; 
             msg.scaledCursorX * 300000 => pG1;
             //ctrlValue * 250000 => pG1;
             Math.min(pG1, 300000) => pG1;
             mem.changePG(pG1); 
             mem2.changePG(pG1);
             //<<<mem.pG + "   tens: " + mem.curT>>>;
             
             // messages received
             if( hi.recv( msg ) )
             {
                 // mouse motion
                 if( msg.isMouseMotion() )
                 {    
                     mem.initT*0.5 + (1.0-msg.scaledCursorY)*mem.initT*5.0 => float t;
                     mem.changeTension(t);
                     mem2.changeTension(t); 
                 }
             }  
         }  
     }

}