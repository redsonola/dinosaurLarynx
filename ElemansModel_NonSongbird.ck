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

//Syrinx Membrane
class RingDoveSyrinxLTM extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    T/2.0 => float timeStep;
    
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
    0.2 => float l; //length of the trachea
    0.003 => float a01; //lower rest area
    0.003 => float a02; //upper rest area
    2.0*l*w => float a0; 
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
    
    //pressure values
    8 => float Ps; //pressure in the syringeal lumen, 0.008 or 8
    
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
    
    [3.0, 3.0] @=> float cSpringConstants[]; //Steineke & Herzel, 1994  -- ah this is c1, c2. maybe bah-lete this dup.
    
    0.0 => float dU;
    
    0.00113 => float p; //air density
    
    //need to confirm this, it's not correct yet
    3.0 => float c1; 
    3.0 => float c2; 

    fun void updateU()
    {
       timeStep*(dU + ( 2*l*Math.sqrt((2*Ps)/p)*(heaveiside(a2-a1)*dx[0] + heaveiside(a1-a2)*dx[1]) ) )=> dU;
    }
    
    fun void updateX()
    {
       timeStep * ( d2x[0] + ( (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
       timeStep * ( d2x[1] + ( (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) ) )=> d2x[1];  
     
     //??? does this need smoothing or no?
    //   ( (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) ) => d2x[0]; 
    //   ( (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) ) => d2x[1];  

       
       for( 0=>int i; i<x.cap(); i++ )
       {
           //update dx, integrate
           dx[i] => float dxPrev;
           dx[i] + d2x[i] => dx[i];
           
           //update x, integrate again
           x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 
           //x[i] + dx[i] => x[i]; 

       }
    }
    
    //linear equations that id each plate on the plane xz
    //a1, a2 --syringeal areas at 1st and 2nd mass heights
    //d1 and d1+d2, mass heights
    //aM - syringeal area at height dM
    fun float slope()
    {
        return (x[1]-x[0])/((d1+d2)-d1);
    }
    
    fun float b(float s)
    {
        return x[0] - s*d1 => b;  
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
        else if( z<=d3 )
        {
            return ( (w - x0[1] - x[1])/d3 )*(x0[1] - x[1]) + (x0[0] + x[0]);            
        }
        else return 0.0; 
    }
    
    
    //from diss.
    fun float syringealArea(float z)
    {
        if( z >=0 && z<=d3 )
            return 2.0*l*plateXZ(z); 
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
         d1 - ( (a1*d2)/(a2-a1) ) =>  cpo2; 
         d1 + d2 - ( (a2*d3)/(a0-a2) ) =>  cpo3;  
     }
     
     //replace with equation from diss.
     fun float defIForce(float z0, float z1)
     {
         //try making it work w/heaviside-style if statement ????
         syringealArea(z0) => float aZ0;
         syringealArea(z1) => float aZ1;
   
         if( aZ0 <= 0 || aZ1 <=0 )
         {
             return l*Ps*(z1 - z0); 
         }
         else return l*Ps*(z1 - z0)*(1 - ( (aMin*aMin)/(aZ0*aZ1) )  );
     }
     
     fun float updateForce()
     {
         0.0 => float zM; //ordinate at which aMin is found -- 1 or 2
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
         defIForce(dM, d2) => F[1];
     }
     
     fun void updateCollisions()
     {
         syringealArea(dM) => aM;
         if( a1 > 0.0 && a2 > 0.0 && aM > 0.0 )
         {
             0.0 => I[0];
             0.0 => I[1];             
         }
         else
         {
             updateCPO();
             zM - cpo1 => float L1; 
             cpo3 - zM => float L2; 
             
             -c1/(4*l)*( a1 + (aM*d2)/( 2*L1 ) ) => I[0];
             -c2/(4*l)*( a2 + (aM*d2)/( 2*L2 ) ) => I[1];
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

//1::second => now; 
now => time start;

<<<ltm.defIForce(0, ltm.d1)>>>;
<<<ltm.defIForce(ltm.d1, ltm.dM)>>>;
<<<ltm.defIForce(ltm.dM, ltm.d2)>>>;



while(now - start < 10::second)
{
    <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    1::samp => now;   
}  

