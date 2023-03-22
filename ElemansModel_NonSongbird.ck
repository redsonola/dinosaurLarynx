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
    (T*1000.0)/2.0 => float timeStep; //this is for integrating smoothly, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert
    
    //membrane displacement
    [0.0, 0.0] @=> float x[]; 
    [0.0, 0.0] @=> float dx[]; 
    [0.0, 0.0] @=> float d2x[]; 
    [0.0, 0.0] @=> float F[]; //force
    0.001 => float m; //mass
    [0.0, 0.0] @=> float x0[]; 
    
    //damping and stiffness coefficients 
    0.001 => float r; //damping
    0.02 => float k; //stiffness
    0.005 => float kc; //coupling constant
    
    [0.0, 0.0] @=> float I[]; //collisions
    
    //biological parameters of ring dove syrinx, in cm
    0.15 => float w; //trachea width
    0.3 => float l; //length of the trachea
    0.003 => float a01; //lower rest area
    0.003 => float a02; //upper rest area
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
    
    a01 + 2.0*l*w => float a0; //a0 is the same for both masses since a01 == a02

    //pressure values
    0.008 => float Ps; //pressure in the syringeal lumen, 0.008 or 8
    
    //geometry
    d1 + (d2/2) => float dM; //imaginary horizontal midline -- above act on upper mass, below on lower
    
    //geometries to calculate force
    0.0 => float a1; 
    0.0 => float a2; 
    0.0 => float aMin;
    0.0 => float zM; 
    0.0 => float aM;  
    
    //collision point ordinates
    0.0 => float minCPO; //min. collision point ordinate -- cpo
    0.0 => float cpo1; 
    0.0 => float cpo2; 
    0.0 => float cpo3; 
    0.0 => float cpoM;
        
    0.0 => float dU;
    
    0.00113 => float p; //air density
    
    //Steineke & Herzel, 1994  --this part was not clear there but--->
    //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
    //https://doi.org/10.1063/1.166078
    3.0 * k => float c1; 
    3.0 * k => float c2; 

    fun void updateU()
    {
        if(aMin > 0)
        {
            //breaking up the equation so I can easily see order of operations is correct
            2*l*Math.sqrt((2*Ps)/p) => float firstMult; 
            heaveiside(a2-a1)*dx[0] => float firstAdd; 
            heaveiside(a1-a2)*dx[1]=> float secondAdd;
            
            firstMult*(firstAdd + secondAdd) => dU;
            //( 2*l*Math.sqrt((2*Ps)/p)*(heaveiside(a2-a1)*dx[0] + heaveiside(a1-a2)*dx[1]) )=> dU;
        }
        else
        {
           0 => dU; //current dU is 0, then have to smooth for integration just showing that in the code
        }                
    }
    
    fun void updateX()
    {
       timeStep * ( d2x[0] + ( (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
       timeStep * ( d2x[1] + ( (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) ) ) => d2x[1];  

 //      ( (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) )  => d2x[0]; 
 //      ( (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) )  => d2x[1];  
     
       
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
    
    //find x distance (opening) given z -- from diss.
    fun float plateXZ(float z)
    {
        if(z >= 0 && z <= d1)
        {
            return ( (x0[0] + x[0] - w)/d1 )*z + w;
        }
        else if( z<= d1 + d2 )
        {
            return ( (x0[1] + x[1] - x0[0] - x[0])/d2 )*(z-d1) + (x0[0] + x[0]);
        }
        else if( z<= (d1+d2+d3 ) )
        {
                                        //check this
            return ( (w - x0[1] - x[1])/(d3) )*(z-(d1+d2)) + (x0[1] + x[1]);            
        }
        else return 0.0; 
    }
    
    //find x distance (opening) given z -- from diss.
    fun float plateXZDebug(float z, float x1, float x2)
    {
        if(z >= 0 && z <= d1)
        {
            return ( (x0[0] + x1 - w)/d1 )*z + w;
        }
        else if( z<= d1 + d2 )
        {
            return ( (x0[1] + x2 - x0[0] - x1)/d2 )*(z-d1) + (x0[0] + x1);
        }
        else if( z<=d1+d2+d3 )
        {
            return ( (w - x0[1] - x2)/d3 )*(z-(d1+d2)) + (x0[1] + x2);            
        }
        else return 0.0; 
    }
    
    
    fun float syringealArea(float z)
    {
        if( z >=0 && z<=(d1+d2+d3 ) )
            return a01 + 2.0*l*plateXZ(z); //adding a01, since it equals a02, so don't need to differentiate
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

     fun void updateCPO()
     {
         //find all the CPOs
         (a0*d1)/(a0-a1) =>  cpo1; 
         
         
         //just check this?
         if((a2 - a1) == 0)
             d1 => cpo2; 
         else d1 - ( (a1*d2)/(a2-a1) ) =>  cpo2; 
         
         d1 + d2 - ( (a2*d3)/(a0-a2) ) =>  cpo3;  
     }
     
     fun float stupidAbs(float x)
     {
         if(x < 0)
         {
             return -1 * x;
         }
         else return x; 
     }
     
     //replace with equation from diss.
     fun float defIForce(float z0, float z1)
     {
         //try making it work w/heaviside-style if statement ????
         syringealArea(z0) => float aZ0;
         syringealArea(z1) => float aZ1;
         
//         <<< "aZ0: " + aZ0 >>>;
//         <<< "aZ1: " + aZ1 >>>;
//         <<< "aMin: " + aZ1 >>>;

   
         if( aMin <=0 )
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
                 else if( ( a1 > 0 ) && a1 <= stupidAbs(a2) && min0==cpo2 && cpo2 < dM ) //case 3a
                 {
                     return 0.0; 
                 }
                 else if( a1 > 0  && a1 > stupidAbs(a2) && min0==cpo2 && cpo2 >= dM  )
                 {
                     return l*Ps*( d2/2 * ( (a1+a2)  / (a1-a2) ) ); 
                 }
                 else return l*Ps*( Math.min(min0, z1)  - z0); 
             }
             else return l*Ps*( Math.min(min0, z1)  - z0); 
         }
         else 
         {
            if(  ( ( ( z0==d1 ) && z1==dM  ) || ( z0==dM && z1==(d1+d2) ) ) && (dM == z0)  ) //it's F2
            {
                return 0.0; 
            }
            else return l*Ps*(z1 - z0)*(1 - ( (aMin*aMin)/(aZ0*aZ1) )  );
         }
     }
     
     fun float updateForce()
     {
         syringealArea(d1) => a1;
         syringealArea(d1+d2) => a2;     
 
         if( a1 < a2 )
         {
             a1=> aMin;
             d1 => zM;
         }
         else
         {
             a2 => aMin;
             d1+d2 => zM;             
         }   
         
         defIForce( 0, d1 ) + defIForce(d1, dM) => F[0];
         defIForce(dM, d1+d2) => F[1]; //trying
     }
     
     //recheck w/table
     fun void updateCollisions()
     {  
         syringealArea(dM) => aM;
         if( ( a1 > 0.0 && a2 > 0.0 && aM > 0.0 ) || aMin > 0.0 )
         {
             0.0 => I[0];
             0.0 => I[1];             
         }
         else 
         {
             //this is what makes everything blow up... need to look at this.
             updateCPO();
             dM - cpo1 => float L1; 
             cpo3 - dM => float L2; 

             //look at the original function, look at the heaviside
             if( L1 > 0) //hmmmmmmmm -- look at this, yeees.
             {
                 ( -c1/(4*l) )*( a1 + ( (aM*d2)/( 2*L1 ) ) ) => I[0];
             }
             else 0.0 => I[0];
             
             if(L2 > 0)
             {
                 ( -c2/(4*l) )*( a2 + ( (aM*d2)/( 2*L2 ) ) ) => I[1];
             }
             else 0.0 => I[1];

         }
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

3::second => now; 
now => time start;
while(now - start < 10::ms)
{
  //  <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    //<<< ltm.dU  + " , " + ltm.x[1] + " , " + ltm.x[0] +" , " +  ltm.d2x[1] + " , " + ltm.F[1] + " , " + ltm.I[1] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
   // <<<ltm.x[0] + " , " +  ltm.x[1] + " , " + ltm.cpo1 + " , " + ltm.cpo2 + " , "+ ltm.cpo3 + " , " + ltm.I[0] + " , " + ltm.I[1] + " , " + ltm.zM >>>;
    ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," 
        + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
        
        <<< ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" >>>;
     
    fout.write( output ); 

    1::samp => now;   
}  

// close the thing
fout.close();




