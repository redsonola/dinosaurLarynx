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

//Syrinx Membrane
class RingDoveSyrinxLTM extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    (T*1000.0)/(2.0) => float timeStep; //this is for integrating, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert
    
    //membrane displacement
    [0.0, 0.0] @=> float x[]; 
    [0.0, 0.0] @=> float dx[]; 
    [0.0, 0.0] @=> float d2x[]; 
    [0.0, 0.0] @=> float F[]; //force
    [0.0015, 0.0003] @=>  float m[]; //mass
    [0.0, 0.0] @=> float x0[]; 
    
    //damping and stiffness coefficients 
    0.002 => float r; //damping
    [0.08, 0.008] @=>  float k[]; //stiffness
    0.025 => float kc; //coupling constant
    
    [0.0, 0.0] @=> float I[]; //collisions
    
    //biological parameters of ring dove syrinx, in cm
    0.15 => float w; //trachea width
    0.3 => float l; //length of the trachea
    0.0021 => float a01; //lower rest area
    0.00175 => float a02; //upper rest area
   // a01 + 2.0*l*w => float a0; 
    
    0.1 => float d1; //1st mass height
    0.02 => float d2; //2nd mass displacement from first
        
    //pressure values
    0.008 => float Ps; //pressure in the syringeal lumen, 0.008 or 8
        
    0.0 => float dU;
    0.0 => float U; 
    0.0 => float prevU; 
    0.0 => float intU; //U from integration....
    0.0 => float subDU; //dU from derivation
    0.0 => float testDU1; 
    0.0 => float testDU2; 


    
    0.00113 => float p; //air density
    
    //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
    //https://doi.org/10.1063/1.166078
    3.0 * k[0] => float c1; 
    3.0 * k[1] => float c2;      
    
    0.0 => float aMin; 
    0.0 => float a1; 
    0.0 => float a2; 
    
    
    fun void updateU()
    {
        if(aMin > 0)
        {
            //breaking up the equation so I can easily see order of operations is correct
            2*l*Math.sqrt((2*Ps)/p) => float firstMult; 
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
        sq*aMin*heaveiside(Math.max(0, aMin)) => U;
        U - prevU => subDU; //let's see?
    }
    
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
            
            //update x, integrate again
            x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 
            //    x[i] + dx[i] => x[i]; 
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

    fun float heaveisideA(float val, float a)
    {
        if( val > 0 )
        {
            //return 1.0;
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
        if( aMin <= 0 )
        {
            return Ps; 
        }
        else 
        {
            return Ps * (1 - ( heaveiside(aMin)*(aMin/a1)*(aMin/a1) ) )*heaveisideA(a1, a1); 
        }
    }
    
    fun float updateForce()
    {        
        a01 + 2*l*x[0]=> a1;
        a02 + 2*l*x[1]=> a2; 
        
        Math.min(a1, a2) => aMin;

        pressure()*l*d1 => F[0];
        0 => F[1]; 
    }
    
    //recheck w/table
    fun void updateCollisions()
    {  
       -heaveisideA(-a1, a1)*c1*(a1/( 2*l)) => I[0];
       -heaveisideA(-a2, a2)*c2*(a2/( 2*l)) => I[1];
    }
    
    fun float tick(float in)
    {
        updateX();
        updateForce();
        updateCollisions();
        updateU(); 
        
        return dU; 
    }
}

RingDoveSyrinxLTM ltm => Dyno limiter => dac; 
limiter.limit(); 
100 => limiter.gain; 


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

//10::second => now;
//1::second => now; 
    "x[0]"  + "," + "x[1]" +"," + "dx[0]"  + "," + "dx[1]" + "," + "a1" + "," + "a2" + "," + "dU"  + "," + "U"  + ","  + "intU"  + ","+ "subDU" + ","+"F[0]" + "," + "F[1]" + "," + "I[0]" + "," + "I[1]" + "," +  "testDU1" + "," + "testDU2" + "\n" => string output; 
    fout.write( output ); 

now => time start; 
while(now - start < 10::ms)
{
    
    //  <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    //<<< ltm.dU  + " , " + ltm.x[1] + " , " + ltm.x[0] +" , " +  ltm.d2x[1] + " , " + ltm.F[1] + " , " + ltm.I[1] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    // <<<ltm.x[0] + " , " +  ltm.x[1] + " , " + ltm.cpo1 + " , " + ltm.cpo2 + " , "+ ltm.cpo3 + " , " + ltm.I[0] + " , " + ltm.I[1] + " , " + ltm.zM >>>;
    ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.U  + "," + ltm.intU  + "," + ltm.subDU  + "," + ltm.F[0] + "," + ltm.F[1]+ ","  + ltm.I[0] + "," + ltm.I[1]  + "," +  ltm.testDU1*1000.0 + "," + ltm.testDU2 +  "\n" => string output; 
  //  + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
    
    <<< ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.U  + "," + ltm.F[0] + "," + ltm.F[1] + ","+ ltm.I[0] + "," + ltm.I[1] + "\n" >>>;
    fout.write( output ); 
    
    1::samp => now;   
}  

// close the thing
fout.close();




