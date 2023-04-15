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


/*
[1]	D. N. During and C. P. H. Elemans. Embodied Motor Control of Avian Vocal Production. In Vertebrate Sound Production and Acoustic Communication. Springer International Publishing, 119?157, 2016. https://doi.org/10.1007/978-3-319-27721-9_5
*/

//Syrinx Membrane
class RingDoveSyrinxLTM extends Chugen
{
    //time steps
    second/samp => float SRATE;
    1/SRATE => float T; //to make concurrent with Smyth paper
    (T*1000)/2 => float timeStep; //this is for integrating smoothly, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert

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
    0.3 => float l; //length of the trachea
    0.003 => float a01; //lower rest area
    0.003 => float a02; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx
    0.04 => float d1; //1st mass height
    0.24 - d1 => float d2; //2nd mass displacement from first
    0.28 - (d1+d2) => float d3; //3rd mass displacement from 2nd
    
    2.0*l*w => float a0; //a0 is the same for both masses since a01 == a02

    //pressure values - limit cycle is half of predicted? --> 0.00212.5 to .002675?
    //no - 0.0017 to 0.0031 -- tho, 31 starts with noise, if dividing by 2 in the timestep
    0.0043 => float Ps; //pressure in the syringeal lumen, 0.004 is default Ps for this model but only 1/2 of predicted works
    
    //geometry
    d1 + (d2/2) => float dM; //imaginary horizontal midline -- above act on upper mass, below on lower
    
    //geometries to calculate force
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
            heaveisideA(a2-a1, a1)*dx[0] => float firstAdd; 
            heaveisideA(a1-a2, a2)*dx[1]=> float secondAdd;
            
            firstMult*(firstAdd + secondAdd) => dU;
        }
        else
        {
           0 => dU; //current dU is 0, then have to smooth for integration just showing that in the code
        }                
    }
    
    fun void updateX()
    {
       //update d2x/dt
       timeStep * ( d2x[0] + ( (1.0/m) * ( F[0] - r*dx[0] - k*x[0] + I[0] - kc*( x[0] - x[1] )) ) ) => d2x[0]; 
       timeStep * ( d2x[1] + ( (1.0/m) * ( F[1] - r*dx[1] - k*x[1] + I[1] - kc*( x[1] - x[0] )) ) ) => d2x[1];  
              
       for( 0=>int i; i<x.cap(); i++ )
       {
           //update dx, integrate
           dx[i] => float dxPrev;
           dx[i] + d2x[i] => dx[i];
           
           //update x, integrate again
           x[i] + timeStep*(dxPrev + dx[i]) => x[i]; 
       }
    }
/*
Not using right now...... but may use later as more general purpose

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

//this should be equivalent to the above, but using here right now to completely avoid magical thinking
fun float syringealArea(float z)
{
    if( z==0 || z==(d1+d2+d3) )
        return a0; 
    else if(z == d1)
        return a1; 
    else if(z == (d1+d2))
        return a2; 
    else if(z == dM )
        return aM; 
    else
    {
        <<< "Error! Called area for unkown value. Need to modify code" >>>;
        return 0.0; 
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
     
     //from Steinecke, et. al  1994 --> a smoothing heaveside not sure if this is important yet.
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
         syringealArea(z0) => float aZ0;
         syringealArea(z1) => float aZ1;

         if( aMin <=0 ) //closed configuration
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
                 else if( ( a1 > 0 ) && a1 <= Math.fabs(a2)  && min0==cpo2 && cpo2 <= dM ) //case 3a
                 {
                     return 0.0; 
                 }
                 else if( a1 > 0  && a1 > Math.fabs(a2) && min0==cpo2 && cpo2 > dM  ) //case 3b
                 {
                     return l*Ps*( d2/2 * ( (a1+a2)  / (a1-a2) ) ); 
                 }
                 else return l*Ps*( Math.min(min0, z1)  - z0); 
             }
             else //it's F1
             {
                 if( ( a1 > 0 ) && a1 <= Math.fabs(a2) && min0==cpo2 && cpo2 <= dM ) //case 3a
                 {
                     return l*Ps*( d1 + d2*( a1/( a1-a2 ) ) );
                 }
                 else if( a1 > 0  && a1 > Math.fabs(a2) && min0==cpo2 && cpo2 > dM  ) //case 3b
                 {
                     return l*Ps*dM;
                 }
                 else if ( a1 <= 0 && min0==cpo1 && cpo1 < z1) //case 4
                 {
                     return l*Ps*d1*( a0/(a0-a1));
                 }
                 else 
                 {
                     return l*Ps*( Math.min(min0, z1)  - z0); 
                 }
             }
         }
         else //open configuration
         {
             if(  ( ( ( z0==d1 ) && z1==dM  ) || ( z0==dM && z1==(d1+d2) ) ) && (zAMin == z0)  ) //it's F2 & case 1
             {
                 return 0.0; 
             }
             else return l*Ps*(z1 - z0)*(1 - ( (aMin*aMin)/(aZ0*aZ1) )  );
         }
     }
     
     fun float updateForce()
     {
         //find current areas according to p. 106
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
         
         defIForce( 0, d1 ) + defIForce(d1, dM) => F[0];
         defIForce(dM, d1+d2) => F[1]; //trying
     }
     
     //TODO: recheck this w/table
     fun void updateCollisions()
     {           
           
         //this is what makes everything blow up... need to look at this.
         dM - cpo1 => float L1; 
         cpo3 - dM => float L2; 
         
         if( a1>=0 && aM >=0)
         {
             0.0 => I[0];
         }
         else if( a1>=0 && aM < 0 )
         {
             ( -c1/(4*l) )*aM => I[0];
         } 
         else
         {
             ( -c1/(4*l) )*( a1 + ( (aM*d2)/( 2*L1 ) ) ) => I[0];
         }
         
         if( a2>=0 && aM >=0)
         {
             0.0 => I[1];
         }
         else if( a2>=0 && aM < 0 )
         {
             ( -c2/(4*l) )*aM => I[1];
         }
         else
         {
             ( -c2/(4*l) )*( a2 + ( (aM*d2)/( 2*L2 ) ) ) => I[1];                 
         }
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

RingDoveSyrinxLTM ltm => Dyno limiter => dac; 
limiter.limit(); 


/*
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
*/


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

    "x[0]"  + "," + "x[1]" +"," + "dx[0]"  + "," + "dx[1]" + "," + "a1" + "," + "a2" + "," + "dU"  + ", "+"F[0]" + "," + "F[1]" + "," + "I[0]" + "," + "I[1]" +"\n" => string output; 
    fout.write( output );

5::second => now; 
now => time start;
while(now - start < 1000::ms)
{
  //  <<< ltm.dU  + " , " + ltm.x[0] + " , " +  ltm.d2x[0] + " , " + ltm.F[0] + " , " + ltm.I[0] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
    //<<< ltm.dU  + " , " + ltm.x[1] + " , " + ltm.x[0] +" , " +  ltm.d2x[1] + " , " + ltm.F[1] + " , " + ltm.I[1] + " , " + ltm.a1 + " , " + ltm.a2 + " , " + ltm.zM >>>;
   // <<<ltm.x[0] + " , " +  ltm.x[1] + " , " + ltm.cpo1 + " , " + ltm.cpo2 + " , "+ ltm.cpo3 + " , " + ltm.I[0] + " , " + ltm.I[1] + " , " + ltm.zM >>>;
 //   ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," 
//        + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
        
  //      <<< ltm.dU  + "," + ltm.x[0]  + "," + ltm.x[1] +"," + ltm.F[0] + "," + ltm.F[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.cpo1 + "," + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" >>>;
     
    
    
        ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.F[0] + "," + ltm.F[1]+ ","  + ltm.I[0] + "," + ltm.I[1]  + "," +  "\n" => string output; 
  //  + ltm.cpo2 + ","+ ltm.cpo3 + "," + ltm.I[0] + "," + ltm.I[1] + "," + ltm.zM + "\n" => string output; 
    
    <<< ltm.x[0]  + "," + ltm.x[1] +"," + ltm.dx[0]  + "," + ltm.dx[1] + "," + ltm.a1 + "," + ltm.a2 + "," + ltm.dU  + "," + ltm.F[0] + "," + ltm.F[1] + ","+ ltm.I[0] + "," + ltm.I[1] + "\n" >>>;
    fout.write( output ); 
    
    
    fout.write( output ); 

    1::samp => now;   
}  

// close the thing
fout.close();

//TODO for tomorrow:
//1. Check expectations, this is close -- but I only skimmed that part
//2. recheck collision equations --> check
//3. recheck parameters and initial conditions --> check
//4. recheck forces agains --> check




