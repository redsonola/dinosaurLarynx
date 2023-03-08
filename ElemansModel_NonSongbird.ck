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

//Syrinx Membrane
class RingDoveSyrinxLTM extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    
    //membrane displacement
    [0.0, 0.0] @=> float x[]; 
    [0.0, 0.0] @=> float dx[]; 
    [0.0, 0.0] @=> float d2x[]; 
    [0.0, 0.0] @=> float F[]; //force
    0.001 => float m; //mass
    
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
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
    
    //pressure values
    0.0 => float Ps; //pressure in the syringeal lumen
    
    //geometry
    d1 + (d2/2) => float dM; //imaginary horizontal midline -- above act on upper mass, below on lower
    
    //geometries to calculate force
    0.0 => float a1; 
    0.0 => float a2; 
    0.0 => float aMin;
    0.0 => float zM; 
    0.0 => float min0;  
    0.0 => float aM;  
    [3.0, 3.0] => float cSpringConstants; //Steineke & Herzel, 1994 

    
    
    fun void updateX()
    {
        (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) => d2x[0]; 
        (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) => d2x[1];  
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
    fun float plateXZ(float z)
    {
        slope() => float s;
        return s*z + b(s); 
    }

    fun float syringealArea(float z)
    {
        return 2.0*l*plateXZ(z); 
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
/*
     fun void pressure(float z)
     {
         0.0 => float zM; //ordinate at which aMin is found -- 1 or 2
         syringealArea(d1) => float a1;
         syringealArea(d1+d2) => float a2;

         if( a1 < a2 )
         {
             a1=> aMin;
             d1 => zM;
         }
         else
         {
             a1 => aMin;
             d1+d2 => zM;             
         }

         if (aMin > 0)
         {
             ( aMin / syringealArea(z) ) => float sAreaRatio;
             pS*( 1 - sAreaRatio*sAreaRatio )*heaveiside( zM - z );
         }
         else
         {
            minOrd() => float minCollisionOrd; //minimum ordinate z for which a(z) <= 0
            pS*heaveiside( minCollisionOrd );
         }
     }
*/
     
     //P(z), integrated
     fun float forceX(float z)
     {
         x[0] => float x1; 
         x[1] => float x2; 
         
         float F; 
         
         //p(z) integrated via sympy, and not simplified so this is messy
         if( aMin > 0 )
         {
             if( z < zM )
             {
                  (Ps*z) + (Ps*aMin*aMin*x1*x1 - 2*Ps*aMin*aMin*x1*x2 + Ps*aMin*aMin*x2*x2)/(-4*Math.pow(d1,3)*l*l + 8*d1*d1*d2*l*l - 4*d1*d2*d2*l*l 
                  + 4*d1*l*l*x1*x1 - 4*d1*l*l*x1*x2 - 4*d2*l*l*x1*x1 + 4*d2*l*l*x1*x2 + z*(4*d1*d1*l*l - 8*d1*d2*l*l + 4*d2*d2*l*l)) => F;
             }
             else
             {
                 (Ps*zM) + (Ps*aMin*aMin*x1*x1 - 2*Ps*aMin*aMin*x1*x2 + Ps*aMin*aMin*x2*x2)/(-4*Math.pow(d1,3)*l*l + 8*d1*d1*d2*l*l - 4*d1*d2*d2*l*l + 
                 4*d1*l*l*x1*x1 - 4*d1*l*l*x1*x2 - 4*d2*l*l*x1*x1 + 4*d2*l*l*x1*x2 + zM*(4*d1*d1*l*l - 8*d1*d2*l*l + 4*d2*d2*l*l)) => F;    
             }
         }
         else
         {
             updateMin0();
             if( min0 > z )
             {
                 Ps*z => F; 
             }
             else 
             {
                 Ps*min0 => F;
             }
         } 
         return F;      
     }
    
     fun void updateMin0()
     {
         0.0 => float m; 
         0.0 => float b1; 

         if(a1<=0)
         {
             d1/x[0] => m; 
             x[0] - m*d1 => b1;
             -b1/m => min0; 
         }
         else
         {
            slope() => m; 
            -b(m)/m => min0; 
         }
     }
     
     fun float defIForce(float z0, float z1)
     {
         return l*(forceX(z1) - forceX(z0)); 
     }
     
     fun float updateForce()
     {
         0.0 => float zM; //ordinate at which aMin is found -- 1 or 2
         syringealArea(d1) => a1;
         syringealArea(d1+d2) => a2;     
         float min0; 
 
         
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
     
     float void updateCollisions()
     {
         syringealArea(dM) => aM;
         if( a1 > 0 && a2 > 0 && aM > 0 )
         {
             0.0 => I[0];
             0.0 => I[1];             
         }
         
         //ok, now need to write for the nonzero part.
     }
    
    fun float tick(float in)
    {
        updateX();
        updateForce();
        
    }
}