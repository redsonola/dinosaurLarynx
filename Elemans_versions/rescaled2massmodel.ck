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

//Syrinx Membrane
class RingDoveSyrinxLTM extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/(SRATE*100) => float T; //to make concurrent with Smyth paper
    (T*1000)/(2.0) => float timeStep; //this is for integrating, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert
    
    //membrane displacement
    [0.0, 0.0] @=> float x[]; 
    [0.0, 0.0] @=> float dx[]; 
    [0.0, 0.0] @=> float d2x[]; 
    [0.0, 0.0] @=> float F[]; //force
    [0.0015, 0.0003] @=>  float m[]; //mass - m1 1st mass  0.0015 g, m2 2nd mass  0.0003 g
    
    //damping and stiffness coefficients 
    0.002 => float r; //damping - r damping constant (r1 = r2)  0.002 g/ms
    [0.08, 0.008] @=>  float k[]; //stiffness - k1 1st mass stiffness  0.08 g/ms2, k2 2nd mass stiffness  0.008 g/ms2
    0.025 => float kc; //coupling constant - kc coupling constant   0.025 g/ms2
    
    [0.0, 0.0] @=> float I[]; //collisions
    
    //biological parameters of ring dove syrinx, in cm
    0.3 => float l; //length of the trachea - l length of the syringeal lumen 0.3 cm
    0.0021 => float a01; //lower rest area -- a01 lower rest area 0.0021 cm2
    0.00175 => float a02; //upper rest area -- a02 upper rest area 0.00175 cm2
    
    0.1 => float d1; //1st mass height  d1 1st mass thickness-  0.1 cm
    0.02 => float d2; //2nd mass displacement from first - d2 2nd mass thickness 0.02 cm
        
    //pressure values
    0.0066 => float Ps; //pressure in the syringeal lumen, 0.008 or 8 --> however, works around 0.006 instead
        
    0.0 => float dU;
    0.0 => float prevDU;
    0.0 => float prevPrevDU; 
    0.0 => float U; 
    0.0 => float prevU; 
    0.0 => float intU; //U from integration....
    0.0 => float subDU; //dU from derivation
    0.0 => float testDU1; 
    0.0 => float testDU2; 
    
    0.00113 => float p; //air density
    
    //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
    //https://doi.org/10.1063/1.166078
    //https://watermark-silverchair-com.proxy.libraries.smu.edu/1874_1_online.pdf
    3.0 * k[0] => float c1; 
    3.0 * k[1] => float c2;  
    
    0.0 => float aMin; 
    0.0 => float a1; 
    0.0 => float a2; 
  
      
    fun void updateU()
    {
        prevDU => prevPrevDU; 
        dU => prevDU;
        
        if(aMin > 0)
        {
            //breaking up the equation so I can easily see order of operations is correct
            (2*Ps)/p => float insideSq;
            2*l*Math.sqrt(insideSq) => float firstMult; 
            heaveiside(a2-a1)*dx[0] => float firstAdd; 
            heaveiside(a1-a2)*dx[1]=> float secondAdd;
            
            //timeStep*(dU + (firstMult*(firstAdd + secondAdd)) )=> dU;
            firstMult*(firstAdd + secondAdd) => dU; 

            //( 2*l*Math.sqrt((2*Ps)/p)*(heaveiside(a2-a1)*dx[0] + heaveiside(a1-a2)*dx[1]) )=> dU;
        }
        else
        {
            //timeStep*(dU + 0)=> dU; //current dU is 0, then have to smooth for integration just showing that in the code
            0.0 => dU;
        }
        intU + dU => intU; 
        
        U => prevU;
        Math.sqrt((2*Ps)/p) => float sq; 
        sq*aMin*heaveiside(aMin) => U;
        U - prevU => subDU; //NOTE: this verifies that the differentiation was correct for dU -- it's a noisier version of same signal
    }
    
    //update x -- uses equations of oscillating motion (Zaccharelli/Steinke&Herzel,1995), plus integration via trapazoidal rule to find x (Smyth, 2004)
    fun void updateX()
    {
        timeStep * ( d2x[0] + ( (1.0/m[0]) * ( F[0] - r*dx[0] - k[0]*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
        timeStep * ( d2x[1] + ( (1.0/m[1]) * ( F[1] - r*dx[1] - k[1]*x[1] + I[1] - kc*( x[1] - x[0] )) ) ) => d2x[1];  
        
        //      ( (1.0/m[0]) * ( F[0] - r*dx[0] - k[0]*x[0] + I[0] - kc*( x[0] - x[1] )) )  => d2x[0]; 
        //      ( (1.0/m[1]) * ( F[1] - r*dx[1] - k[1]*x[1] + I[1] - kc*( x[1] - x[0] )) )  => d2x[1];  
        
        
        for( 0=>int i; i<x.cap(); i++ )
        {
            //update dx, integrate
            dx[i] => float dxPrev;
            dx[i] + d2x[i] => dx[i];
             
            x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 

        }
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

    //definition of heaviside in an older paper, seems to create closer to the behavior but 
    //this is not the heaviside that the zaccarelli is using according to that paper... 
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
    
    fun float heaveisideAMin(float val)
    {
        return Math.max(val, 0); 
    }
    
    fun float pressure()
    {
//        return Ps * (1 - ( heaveiside(aMin)*(aMin/a1)*(aMin/a1) ) )*heaveiside(a1); 
        return Ps * (1 - ( heaveiside(aMin)*(aMin/a1)*(aMin/a1) ) )*heaveisideA(a1, a01); 
    }
    
    fun float updateForce()
    {        
        a01 + 2*l*x[0]=> a1;
        a02 + 2*l*x[1]=> a2; 
        
        Math.min(a1, a2) => aMin;
        Math.max(aMin, 0) => aMin;

        pressure()*l*d1 => F[0];
        0 => F[1]; 
    }
    
    //recheck w/table
    fun void updateCollisions()
    {  
       -heaveisideA(-a1, a01)*c1*(a1/( 2*l)) => I[0];
       -heaveisideA(-a2, a02)*c2*(a2/( 2*l)) => I[1];        
        
//       -heaveisideA(-a1, a1)*c1*(a1/( 2*l)) => I[0];
//       -heaveisideA(-a2, a2)*c2*(a2/( 2*l)) => I[1];/
//       -heaveiside(-a1)*c1*(a1/( 2.0*l)) => I[0];
//       -heaveiside(-a2)*c2*(a2/( 2.0*l)) => I[1];
    }
    

    
    fun float tick(float in)
    {

        updateForce();
        updateCollisions();
        updateX();
        updateU(); 

        return dU; 
    }
}
//*******sound off bc chuck doesn't work with my headphones and just checking waveforms at the moment.......
RingDoveSyrinxLTM ltm => Dyno limiter => blackhole; //dac
limiter.limit(); 
0.9 => limiter.gain; 
limiter => dac; 


<<< "**********************************" >>>;

FileIO fout;

// open for write
fout.open( "/Users/courtney/Programs/physically_based_modeling_synthesis/out4.txt", FileIO.WRITE );

// test
if( !fout.good() )
{
    cherr <= "can't open file for writing..." <= IO.newline();
    me.exit();
}

//4::second => now; //advance forward a bit
//    "x[0]"  + "," + "x[1]" +"," + "dx[0]"  + "," + "dx[1]" + "," + "a1" + "," + "a2" + "," + "dU"  + "," + "U"  + ","  + "intU"  + ","+ "subDU" + ","+"F[0]" + "," + "F[1]" + "," + "I[0]" + "," + "I[1]" + "," +  "testDU1" + "," + "testDU2" + "\n" => string output; 
//    fout.write( output ); 
    
    
2::second => now; 
now => time start; 
while(now - start < 250000::samp)//10::ms*1000)
{
    
    //  <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    //<<< ltm.dU  + " , " + ltm.x[1] + " , " + ltm.x[0] +" , " +  ltm.d2x[1] + " , " + ltm.F[1] + " , " + ltm.I[1] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
  
    // <<<ltm.x[0] + " , " +  ltm.x[1] + " , " + ltm.cpo1 + " , " + ltm.cpo2 + " , "+ ltm.cpo3 + " , " + ltm.I[0] + " , " + ltm.I[1] + " , " + ltm.zM >>>;
  //  ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.U  + "," + ltm.intU  + "," + ltm.subDU  + "," + ltm.F[0]*1000.0 + "," + ltm.F[1]*1000.0+ ","  + ltm.I[0] + "," + ltm.I[1]  + "," +  ltm.testDU1*1000.0 + "," + ltm.testDU2 +  "\n" => string output; 
  
  //  + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
    
   // <<< ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.U  + "," + ltm.F[0] + "," + ltm.F[1] + ","+ ltm.I[0] + "," + ltm.I[1] + "\n" >>>;
  //  <<<ltm.dU>>>;
  ltm.dU + "\n" => string output; 
    fout.write( output ); 
    
    1::samp => now;   
}  

// close the thing
fout.close();




