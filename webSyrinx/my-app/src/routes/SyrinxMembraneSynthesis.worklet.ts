//Fletcher (1988) / Smyth (2002) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";

//Syrinx Membrane
const syrinxMembraneSynthesis =  /* javascript */`class SyrinxMembrane
{
    //time steps
    protected SRATE : number = 44100;
    protected T : number = 1/this.SRATE; //to make concurrent with Smyth paper
    
    //1.204 => float p; //air density (value used for 68F & atmospheric pressure 101.325 kPa (abs), 1.204 kg/m3
    //0.00118 => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    //1.18 => float p; //over m, air density from Smyt4 diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    //1.18 * Math.pow(10, -3) => float p; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    protected p : number = 0.001225; //air density from Smyth diss., 0.00118cm, 0---- NOTE: Needs to match the input -- meters
    
    //speed of sound (cm/s) 
    protected c : number = 34740; //m //speed of sound from Smyth, 34740 cm/s, so 347.4 m/s,
    
    protected pG : number = 0.0; //pressure from the air sac ==> change to create sound, 0.3 or 300 used in Flectcher 1988, possibly 3 in cm units.


    //main values for differential equation, except for x, defined below in it's own block
    protected p0 : number = 0.0 ; //brochial side pressure
    protected p1 : number = 0.0 ; //tracheal side pressure -- **output that is the time-varying signal for audio 
    protected U : number = 0.0 ; //volume velocity flowing out
   
    //the rate of change that we find at each tick
    protected dp0 : number = 0.0 ; //change in p0, bronchial pressure
    protected dU : number = 0.0 ; //chage in U, volume velocity
    protected d2x : number[] = [0.0, 0.0]; //accel of the membrane per mode
    protected dx : number[] = [0.0, 0.0]; //velocity of the membrane per mode
    
    //initialized to prevent x going to 0
    protected x : number[] = [0.0, 0.0];  //displacement of the membrane per mode
    protected totalX : number = 0.0; // all the x's added for total displacement
    protected F : number = 0.0; //force driving fundamental mode of membrane
    protected x0 : number = 0.0; //equillibrium opening, in cm -- if this is 0.3, close to a -- it does oscillate, but incorrectly
                     //if Force is not added when x is 0, then it will eventually stabilize into a high tone.

    //biological parameters *******
    protected V : number = 1.0; //volume of the bronchius - in cm^3 //oh, yikes, I might change this for the dinosaur.... 
    //[150.0*2.0*pi, 250.0*2.0*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    
    //this one worked for a dino-like sound
    public wFreq : number[] = [200*2.0*Math.PI*.75, 1.6*200*Math.PI*.75]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth
    protected initW : number = this.wFreq[0];  
   
     //  [500*2.0*pi, 1.6*500*pi] @=> float w[]; //radian freq of mode n, freq. of membranes: 1, 1.6, 2 & higher order modes are not needed Fletcher, Smyth


    //coefficients for d2x updates
    protected q1 : number = 2.0; 
    protected k : number = this.wFreq[1]/(this.q1*2.0); //damping coeff. -- k = w1/2*Q1
    //300 => float k; //damping coeff. -- k = w1/2*Q1 //related to freq. & Q instead

    protected E : number = 15; //a number of order 10 to 100 to represent stickiness
    protected membraneNLCoeff : number = 10.0; //membrane non-linear coeff. for masses, etc.
    protected epsilonForceCouple : number[] = [2.0, 1.0]; //try -- mode 1 should be dominant.
    
   
    //3.5 => float a; //  1/2 diameter of trachea, in 3.5mm        ??area of membrane at a point
    protected a : number = 0.35; //  1/2 diameter of trachea, in cm        ??area of membrane at a point

   // 3.5 => float h; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm
   protected h :number = 0.35; //1/2 diameter of the syringeal membrane, 3.5mm, 0.35cm

    //100 => float d; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers
    protected d : number = 0.01; //thickness of the membrane, 100 micrometers, 1mm, 0.01cm -- leave in micrometers, 1mm, decreasing it to 0.01 shows same behavior as 3000pa

    protected L : number = 7.0; //length of the trachea, in 7cm -- HOLD for this one
    
        //c => float pM; //material density of the syrinx membrane, from During, et. al, 2017, itself from mammalian not avian folds, kg/m 
    //0.000102 => float pM; //material density in kg/m^3
    protected pM : number = 1; //values from Smyth 1000.0 kg/m^3, but it should be g/cm3 to match the rest of the units, so 1 g/cm^3
    
    protected m : number[] = [0.0, 0.0] ; //the masses involved in vibration of each mode 
    protected A3: number[] = [0.3, 0.5] ; // constant in the mass equation -- changed bc there was an NAN after membrane density was put into 
    //the correct units from kg/m^3 to g/cm^3
    
    //***** end biological parameters
    
    //tension
    //217.6247770440203 => float initT; //this is the tension to produce 150Hz, the example w in the research articles
    //Math.sqrt( (5*curT) / (pM*a*h*d) ) => w[0]
    protected initT:number = (this.wFreq[0]*this.wFreq[0]*this.pM*this.a*this.h*this.d)/5; //this is the tension to produce 150Hz, the example w in the research articles
    public curT:number = this.initT; //tension to produce the default, in N/cm^3
    protected goalT : number = 0.0;//the tension to increase or decrease to    
    protected dT :number = 0.0 ; //change in tension per sample  
    protected modT : number = 10.0; //how fast tension can change
    protected diff :number = 0.0;
    
    //changing pG
    protected goalPG: number  = 0.0 ;//the tension to increase or decrease to    
    protected dPG: number  =  0.0; //change in tension per sample 
    protected modPG : number = 100.0 ; //a modifier for how quickly dx gets added
    
        
    //impedences
    protected z0 : number = (this.p*this.c)/(Math.PI*this.a*this.a); //impedence of bronchus --small compared to trachea, trying this dummy value until more info 
    protected zG : number = this.z0/12 ; //an arbitrary impedance smaller than z0, Fletcher
     
     protected inP1 : number = 0.0; //to output for debugging     
     protected forceComponent : number = 0.0 ; 
     protected stiffness : number = 0.0; 
     protected moreDrag: number = 0.0; 
     
     protected testAngle : number = 0.0 ; 
     
     protected timeStep : number = (this.T/2.0); 

     
     public initZ0() : void 
    {
       this.z0 = (this.p*this.c)/(Math.PI*this.a*this.a); 
    }
              
    public initTension() : void 
    {
        this.initT = (this.initW*this.initW*this.pM*this.a*this.h*this.d)/5;
        this.goalT = this.initT; 
    }     
         
    protected updateForce() : void 
    {
        //set the force -- the limit of the pU^2/7(ax^3)^(1/2) term is 0 when U is 0 -- this is the only way there would 
        //be force with x=0 -- this is not clear in the texts.
        
        //need to consider the force -- at y=0, upstream (p1), F = 2ahp1
        //and downstream -- integrate pressure along y
        // p(y) = p0 + p/2(U/pi*a^2)^2 - (U/2az(y^2)^2)
        // z(y) = x + (a-x)(y/h)^2
        
        //for Fletcher force equation
        let A1 : number = 1; 
        
        //totalX + x0 => float x; 
        let x : number = this.totalX;
        
        if( x > 0.0 )
        {
           this.F = this.a*this.h*(this.p0 + this.p1) - (2.0*this.p*this.U*this.U*this.h)/(7.0*Math.pow(this.a*x, 1.5)); //-- Smyth (just reduced from Fletcher)
           //memArea* ( ( pressureDiff ) - ( UFactor/overArea  ) ) => F; //fletcher
         }
         else this.F = 0.5*this.a*this.h*(this.p0 + this.p1); //not sure, but divided by 2 produced the results
         
     }
     
    protected updateBrochialPressure() : void 
    {        
        let physConstants : number = (this.p*this.c*this.c) / this.V  ; 
        let preshDiff = (this.pG - this.p0) / this.zG ; 

        this.dp0 = this.timeStep*( this.dp0 + (physConstants * (preshDiff-this.U) )) ; 
        
        this.p0 += this.dp0 ; //this is correct, below is incorrect, but keep this way for now to prevent blow-up
    }
    
    protected updateU() : void
    {
        //<<< "before U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;
     
        if( this.totalX > 0.0 )
        {
            let dUPrev : number = this.dU; 
        
            let C : number = this.p/(8.0*this.a*this.a*this.totalX*this.totalX); //from Fletcher 
            let D : number = ( 2.0 *Math.sqrt( this.a*this.totalX ) )/this.p; //actually inverse
  
            //from Fletcher and Smyth -- mas o menos
            this.dU = this.timeStep*( this.dU + ( D * ( this.p0-this.p1-( C*this.U*this.U ) ) ) ) ; //0 < x <= a
            
             //integrate
             this.U += this.dU ; 
        
        }
        else
        { 
            this.dU = 0.0 ;   
            this.U = 0.0 ;          
        }
        
        //is this a fudge, or is this real?
        if ( this.U < 0 )
        {
            this.U = 0.0 ;             
        }


        //<<< "after U: " + "x: "  + totalX + " p0: " + p0 + " p1: " + p1 + " U: " + U + " dU " + dU >>>;

 
    }
    
    protected updateMass() : void
    {
        for( let i=0; i < this.x.length ; i++ )
        {
            let square : number = (this.x[i]-this.x0)/this.h; 
            let squared : number = square*square ;
            
            this.m[i] = (this.A3[i]*this.pM*Math.PI*this.a*this.h*this.d)/4 ;
            //0.0045 => m[i];
            this.m[i] = this.m[i] * ( 1 + ( this.membraneNLCoeff*squared) ) ; 
        }
        
    }
    
    protected updateX() : void
    {
        this.totalX = 0.0;

        for( let i =0 ; i < this.x.length ; i++ )
        {
            
            let modifiedK : number = this.k;
            if( this.x[i] <= 0 )
            {
                modifiedK = this.k*this.E;
            }

            //update d2x
            //epsilon is taken as unity
            this.forceComponent  = ( this.F*this.epsilonForceCouple[i] ) / this.m[i]  ; 
            this.stiffness = ( - 2.0*modifiedK*this.dx[i]  ) ; 
            this.moreDrag = (- this.wFreq[i]*this.wFreq[i]*(this.x[i]-this.x0) ); 
           
            let nextDx2 : number = this.forceComponent + this.stiffness + this.moreDrag ;
            this.d2x[i] = this.timeStep*(this.d2x[i] + nextDx2);
                        
            //update dx, integrate
            let dxPrev:number = this.dx[i] ;
            this.dx[i] += this.d2x[i];
            
            //update x, integrate again
            this.x[i] += this.timeStep*(dxPrev + this.dx[i]); 
            this.totalX += this.x[i];

        }
        this.totalX += this.x0;
    }
    
    protected updateP1() : void
    {
        this.p1 = this.U*this.z0;
    }
    
    public tick(inSample : number) : number
    {
        if(Number.isNaN(inSample))
        {
            inSample = 0 ;
        }

        this.p1 = inSample ;
        this.inP1 = this.p1; 
                         
        this.updateBrochialPressure();
        this.updateU();
        
        //update x & params needed for x
        this.updateForce(); 
        this.updateMass();
        this.updateX();

        this.updateP1(); 
        
        //user changing parameters
        this.updateTensionAndW(); //-->TODO: need to uncomment when ready to implement tension
        this.updatePG();

        return this.p1;
    }
    
    //changes tension thus, frequency
    public changeTension(tens : number) : void
    {
        this.goalT = tens; 
    }
    
    protected updateTensionAndW() : void
    {
        let diff = this.goalT - this.curT;
        if(diff != 0)
        {            
            //so, try this?
            this.dT = (this.dT + diff)*this.T*this.modT; 
            this.curT = this.curT + this.dT ; 

        
            this.wFreq[0] = Math.sqrt( (5*this.curT) / (this.pM*this.a*this.h*this.d) ) ; //Smyth diss.
            // w[0]*1.6 => w[1]; //Fletcher1988     
            this.wFreq[1] = this.wFreq[0]*1.6; //this is essentially the same thing, but nevertheless, as this is how I discovered frequencies that 
            //better fit the dimensions   
        }    
    }
    
    //changes the air flow
    public changePG(npG : number) : void
    {
        this.goalPG = npG ; 
    }
    
    protected updatePG() : void
    {
        let diff : number = this.goalPG - this.pG ; 
        this.dPG = (this.dPG + diff)*this.T*this.modPG ; 
        this.pG += this.dPG ;      
    }

}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneSynthesis, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


