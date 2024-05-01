//Elemans, Zacharelli, Herzel (2006-9) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";
import "SyrinxMembraneSynthesis.worklet";

export const syrinxDoveMembraneGenerator = /* typescript */  `class RingDoveSyrinx extends SyrinxMembrane
{
    //difference in scale btw dove and dinosaur
    protected dinoScale : number = 4.5/0.15; //ratio based on trachea width ratio btw dove and dinosaur (Corythosaurus)
    protected kc : number;//coupling constant, table C.1 (before, 0.005)
    protected r : number; //damping, table C.1 // 0.0012 => float r; --> moved it back to human, previously
    protected w : number; //1/2 trachea width -- Corythosaurus
    protected l : number; //trachea length involved in membrane
    protected a01 : number; //lower rest area
    protected a02 : number; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx
    protected d1 : number; //1st mass height -- alligator is: d1=0.25, d2=0.05cm -- perhaps this actually doesn't scale up that much? leave alone for now.
    protected d2 : number; //2nd mass displacement from first
    protected d3 : number; //3rd mass displacement from 2nd
    protected I : number[] = [0.0, 0.0]; //collsion

    protected ptl : number;
    protected minPtl : number;
    protected maxPtl : number;
    protected goalPtl : number;
    protected dPtl : number;
    protected modPtl : number;

    protected a0min : number = 0.5; //0.8 for dove
    protected a0max : number = 3; //1.2 for dove
    protected a0Change : number = this.a0max - this.a0min; //1.2 for dove

    protected Qmin : number = 0.5; //0.8 for dove
    protected Qmax : number = 3; //1.2 for dove
    protected Q : number = this.Qmin; //F(t) = Q(t)F0
    protected pt : number = -0.3; //-1 to 0.5 using CTAS, normalized to 1, max but usually around 0.5 max -- from graph on p. 70, Pt = PICAS - PCTAS (max 3.5),
    protected Psum : number; //Pt + ptl
    protected minPsum : number;
    protected maxPsum : number;
    protected Qchange : number = this.Qmax - this.Qmin;

    protected goalPt : number;
    protected dPt : number;
    protected modPt : number;

    //NOTE: see if this variable is actually used here.
    protected a0 : number; //area of opening of syrinx at rest

    protected Ps : number; //pressure in the syringeal lumen,
    protected goalPs : number;
    protected dPs : number;
    protected modPs : number;

    protected dM : number; //imaginary horizontal midline -- above act on upper mass, below on lower

    //geometries (ie, areas) found in order to calculate syrinx opening and closing forces
    protected a1 : number = 0;
    protected a2 : number = 0;
    protected aMin : number = 0;
    protected zAMin : number = 0;   
    protected aM : number = 0;
    protected a3 : number = 0;

    //collision point ordinates
    protected minCPO = 0.0; //min. collision point ordinate -- cpo
    protected cpo1 = 0.0;
    protected cpo2 = 0.0;
    protected cpo3 = 0.0;

    //measures of air flow. dU is the audio out   
    protected dU : number = 0.0;
    protected U : number = 0.0;
    protected p : number = 0.0; //this is reflection from vocal tract 
    
    protected z0 : number = 0.0; //impedence of brochus --small compared to trachea, trying this dummy value until more info
    protected zG : number = 0.0; //an arbitrary impedance smaller than z0, Fletcher
    protected pAC : number = 0.0; //reflected pressure from the vocal tract after coupling - incl. impedence, etc. //is this used? 

    protected c1 : number = 0.0; //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality
    protected c2 : number = 0.0; //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality
    
    protected inputP : number = 0.0;

    constructor()
    {
        super();
        this.timeStep = (this.T*1000.0)/2.0; //this is for integrating smoothly, change from Smyth (eg.*1000) bc everything here is in ms not sec, so convert
        this.F = [0.0, 0.0]; //membrane displacement force

        //********* constants that change during modeling the coo!!! 2/2024 Table C.1 p. 134 ************ NOW CORYTHOSAURUS - 3/2024 *************
        this.m = [0.0017 * this.dinoScale]; //mass, table C.1
        this.k = 0.022; //stiffness -- orig. 0.02 in fig. 3.2 zaccharelli -- now back to original-ish? table C.1
        this.kc = 0.006; //coupling constant, table C.1 (before, 0.005)
        this.r = 0.1 * Math.sqrt(this.m[0]*this.k); //damping, table C.1 // 0.0012 => float r; --> moved it back to human, previously
       
        //biological parameters of ring dove syrinx, in cm -- ***change during coo! Table 4.1, p76
        this.w = 4.5;//1/2 trachea width -- Corythosaurus
        this.a = 2*this.w;//full trachea width
        this.l = 21.6; //length of the trachea, 4.1 table, 0.32 **changed, 8.9-14in. med. 11.45", 31-37" (nose to end of body, not tail) alligator is 1.2cm, 3-4x that of a dove, 18x that for Corythosaurus (est. 6m nose to end of body not tail)?? 24-32.4
        this.a01 = 0.003 * 18; //lower rest area
        this.a02 = 0.003 * 17; //upper rest area, testing a02/a01 = 0.8, testing a convergent syrinx

        //heights -- alligator was not much changed from dove (although one is syrinx & one is larynx, hard to measure) humans were less than 2x alligator although much bigger, dunno
        //it does not seem like these heights scale up a lot with size
        //I need to do more research. I've chosen a really conservative number
        this.d1 = 0.04 * 3; //1st mass height -- alligator is: d1=0.25, d2=0.05cm -- perhaps this actually doesn't scale up that much? leave alone for now.
        this.d2 = (0.24 - this.d1)* 3; //2nd mass displacement from first
        this.d3 = (0.28 - (this.d1+this.d2))* 3; //3rd mass displacement from 2nd

        //time-varying (control) tension parameters (introduced in ch 4 & appendix C)
        this.ptl = 19.0; //stress due to the TL tracheolateralis (TL) - TL directly affects position in the LTM -- probably change in dinosaur.
        this.minPtl = 0.0; 
        this.maxPtl = 40.0; 

        //changing Ptl
        this.goalPtl= this.ptl; //the tension to increase or decrease to    
        this.dPtl = 0.0; //change in tension per sample -- only a class variable so can check value. 
        this.modPtl = 5.0; //a modifier for how quickly dx gets added
        
        //more time-varying parameters -- vary with different muscle tension values
        this.a0min = -0.03 * this.dinoScale; 
        this.a0max = 0.01 * this.dinoScale; 
        this.a0Change = this.a0max - this.a0min; 

        //time-varying (input control) parameters Q, which reflect sum of syringeal pressures & resulting quality factor impacting oscillation eq. in updateX()
        this.Qmin = 0.5; //0.8 for dove
        this.Qmax = 3; //1.2 for dove
        this.Q = this.Qmin; //F(t) = Q(t)F0
        this.pt = -0.3; //-1 to 0.5 using CTAS, normalized to 1, max but usually around 0.5 max -- from graph on p. 70, Pt = PICAS - PCTAS (max 3.5), 
        this.Psum = this.pt + this.ptl;
        this.minPsum = 0.0;
        this.maxPsum = 40.0 ; 
        this.Qchange = this.Qmax - this.Qmin;

        //changing Pt
        this.goalPt = this.pt;//the tension to increase or decrease to    
        this.dPt = 0.0; //change in tension per sample -- only a class variable so can check value. 
        this.modPt = 5.0; //a modifier for how quickly dx gets added

        //area of opening of syrinx at rest
        this.a0 = 2.0*this.l*this.w; //a0 is the same for both masses since a01 == a02 --> shit, not anymore. check this.        
    
        //Ps -- the input air pressure below syrinx
        //pressure values - limit cycle is half of predicted? --> 0.00212.5 to .002675?
        //no - 0.0017 to 0.0031 -- tho, 31 starts with noise, if dividing by 2 in the timestep
        this.Ps = 0.0045; //pressure in the syringeal lumen, 

         //changing Ps -- the input air pressure below syrinx
        this.goalPs = this.Ps;//the tension to increase or decrease to    
        this.dPs = 0.0; //change in tension per sample -- only a class variable so can check value. 
        this.modPs = 5.0; //a modifier for how quickly dx gets added

        //0.004 is default Ps for this model but only 1/2 of predicted works in trapezoidal model for default params (?)
        //0.02 is the parameter for fig. C3 & does produce sound with the new time-varying tension/muscle pressure params
    
        //geometry
        this.dM = this.d1 + (this.d2/2); //imaginary horizontal midline -- above act on upper mass, below on lower
    
        this.z0 = (this.p*this.c*100)/(Math.PI*this.a*this.a); //impedence of brochus --small compared to trachea, trying this dummy value until more info 
        this.zG = this.z0/6;

        //Steineke & Herzel, 1994  --this part was not clear there but--->
        //confirmed! Herzel, H., Berry, D., Titze, I., & Steinecke, I. (1995). Nonlinear dynamics of the voice: Signal analysis and biomechanical modeling. Chaos (Woodbury, N.Y.), 5(1), 30?34. 
        //https://doi.org/10.1063/1.166078
        //confirmed in Herzel & Steineke 1995 Bifurcations in an asymmetric vocal-fold model
        //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality

        this.c1 = 3.0 * this.k; //c1 & c2 are constants used in the collision force equations  related to damping/stiffness/materiality
        this.c2 = 3.0 * this.k;
    
    }   
    
    public reset() : void 
    {
        //membrane displacement
        this.x = [0.0, 0.0]; 
        this.dx = [0.0, 0.0]; 
        this.d2x = [0.0, 0.0]; 
        this.F = [0.0, 0.0]; //force  
        this.I = [0.0, 0.0]; //collsion  
        this.dU = 0.0;
        this.U = 0.0; 
       
        //geometries (ie, areas) found in order to calculate syrinx opening and closing forces
        this.a1 = 0.0; 
        this.a2 = 0.0; 
        this.aMin = 0.0;
        this. zAMin = 0.0; 
        this.aM = 0.0;  
        this.a2 = 0.0; 
        this.inputP = 0.0;
    }

    //update the air flow in the syrinx membrane, ie, the U
    //dU, 1st derivative of U, is used as the audio output variable
    protected updateURingDove(Ps : number) : void
    {
        //find du
        if(this.aMin > 0) //note: in some circumstances Ps can be less than zero due to reflections, for now just count as closed membrane...
        {
            Ps = Math.abs(Ps); //disregard direction when calculating overall pressure -- try
            
            //breaking up the equation so I can easily see order of operations is correct
            let firstMult = 2*this.l*Math.sqrt((2*Ps)/this.p);
            let firstAdd = this.heaveisideA(this.a2-this.a1, this.a1)*this.dx[0]; 
            let secondAdd = this.heaveisideA(this.a1-this.a2, this.a2)*this.dx[1];
            
            this.dU = firstMult*(firstAdd + secondAdd);
            
            //find U for vocal tract coupling -- more precise than integrating
            let inside = (2*Ps)/this.p;
            let sq = Math.sqrt(inside); 
            this.U = sq*this.aMin*this.heaveiside(this.aMin);
        }
        else
        {
           this.dU = 0; //current dU is 0, then have to smooth for integration just showing that in the code
           this.U = 0;
        }                
    }
    
    //update the x[], dx[], d2xp[values] - the values describing how open (length-wise) each point (ie, mass) of the syrinx is
    protected updateX() : void
    {
        //for controlling muscle tension parameters
       let mt = this.m[0]/this.Q; //time-varying mass due to muscle tensions, etc.
       let kt = this.k*this.Q; //time-varying stiffness due to muscle tensions, etc.
        
       //update d2x/dt
       this.d2x[0] = this.timeStep * ( this.d2x[0] + ( (1.0/mt) * ( this.F[0] - this.r*this.dx[0] - kt*this.x[0] + this.I[0] - this.kc*( this.x[0] - this.x[1] )) ) ) ; 
       this.d2x[1] = this.timeStep * ( this.d2x[1] + ( (1.0/mt) * ( this.F[1] - this.r*this.dx[1] - kt*this.x[1] + this.I[1] - this.kc*( this.x[1] - this.x[0] )) ) ) ;  
              
       for( let i=0; i<this.x.length; i++ )
       {
           //update dx, integrate
           let dxPrev = this.dx[i];
           this.dx[i] = this.dx[i] + this.d2x[i];
           
           //update x, integrate again
           this.x[i] = this.x[i] + this.timeStep*(dxPrev + this.dx[i]); 
       }
    }

    //heaveside function as described in Zaccarelli(2009)
    protected heaveiside(val : number) : number
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
     
     //from Steinecke, et. al  1994 & 1995 --> a smoothing heaveside not sure if this is important yet. <--NOPE!!!
     protected heaveisideA(val : number, a : number)
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
     
     //finds force 1 - F[0] 
     protected forceF1(min0 : number, Ps : number) : number
     {
         if( this.aMin <=0 ) //closed configuration
         {
             if( ( this.a1 > 0 ) && this.a1 <= Math.abs(this.a2) )// && min0==cpo2 && cpo2 <= dM ) //case 3a
             {
                 return this.l*Ps*( this.d1 + this.d2*( this.a1/( this.a1-this.a2 ) ) );
             }
             else if( this.a1 > 0  && this.a1 > Math.abs(this.a2) )// && min0==cpo2 && cpo2 > dM  ) //case 3b
             {
                 return this.l*Ps*this.dM;
             }
             else if ( this.a1 <= 0)// && min0==cpo1 && cpo1 < d1) //case 4
             {
                 return this.l*Ps*this.d1*( this.a0/(this.a0-this.a1));
             }
             else 
             {
                 return (this.l*Ps*( Math.min(min0, this.d1)  - 0)) + (this.l*Ps*( Math.min(min0, this.dM)  - this.d1)); //check this
             }
         }
         else //open configuration
         {
             if (this.a2 > this.a1 )  //divergent - || ( zAMin == d1 )
             {
                 return this.l*Ps*this.d1*(1 - (( this.a1*this.a1 )/(this.a0*this.a1)) );
             }
            else //convergent
            {
                let part1 = this.d1*(1 - ( (this.a2*this.a2)/(this.a0*this.a1) )  ); 
                let part2 = (this.d2/2)*(1 - ( (this.a2*this.a2)/(this.aM*this.a1) ));
                return this.l*Ps * ( part1 + part2 );
            }
         }
     }
     
     //finds force 1 - F[1] 
     protected forceF2(min0 : number, Ps: number)
     {
         if( this.aMin <= 0) //closed configuration
         {
             if( this.a1 <= 0)// && min0==cpo1 && (cpo1 < d1)) //case 4
             {
                 return 0.0;
             }
             else if( ( this.a1 > 0 ) && (this.a1 <= Math.abs(this.a2)))//  && min0==cpo2 && cpo2 <= dM ) //case 3a
             {
                 return 0.0; 
             }
             else if( this.a1 > 0  && this.a1 > Math.abs(this.a2))// && min0==cpo2 && cpo2 > dM  ) //case 3b
             {
                 return this.l*Ps*( this.d2/2 * ( (this.a1+this.a2)  / (this.a1-this.a2) ) ); 
             }
             else
             {
                  return this.l*Ps*( Math.min(min0, (this.d1+this.d2))  - this.dM); 
              }
         }
         else //open configuration
         {
             if (this.a2 > this.a1)  //divergent || ( zAMin == d1 )
             {
                 return 0.0;
             }             
             else //convergent
             {
                 return this.l*Ps*(this.d2/2)*(1 - ( (this.a2*this.a2)/(this.aM*this.a2)));
             }
         }
     }

    //update the points at which collisions begin
    protected updateCPO()
    {
        //find all the CPOs
        this.cpo1 = (this.a0*this.d1)/(this.a0-this.a1); 
            
        this.cpo2 = this.d1 - ( (this.a1*this.d2)/(this.a2-this.a1) ); 
         
        this.cpo3 = this.d1 + this.d2 - ( (this.a2*this.d3)/(this.a0-this.a2) );  
     }
     
     //update the force for the oscillation equation in updateX()
     protected updateForce() : void
     {
         //find current areas according to p. 106, Zaccarelli, 2009
         let x01 = this.a01/(2*this.l);
         let x02 = this.a02/(2*this.l);
         this.aM = this.l*( this.x[0] + x01 + this.x[1] + x02 ); //the 2.0 cancels out
         
         this.a1 = 2*this.l*(this.x[0]+x01);
         this.a2 = 2*this.l*(this.x[1]+x02);         

         if( this.a1 < this.a2 )
         {
            this.aMin =  this.a1;
            this.zAMin = this.d1;
         }
         else
         {
             this.aMin = this.a2;
             this.zAMin = this.d1+this.d2;;             
         }   
         
         //find min c.p.o
         this.updateCPO();
         let min0 = this.cpo1; 
         min0 = Math.min(min0, this.cpo2);  
         min0 = Math.min(min0, this.cpo3); 
         
         this.F[0] = this.forceF1(min0, this.Ps - this.inputP);
         this.F[1] =this.forceF2(min0, this.Ps - this.inputP); //modifying in terms of equation presented on (A.8) p.110

     }
          
     //Calculate the forces for any vocal fold collisions (I[]), if any
     protected updateCollisions()
     {           
           
         //this is what makes everything blow up... need to look at this.
         let L1 = this.dM - this.cpo1; 
         let L2 = this.cpo3 - this.dM; 
         
         if( this.aMin <= 0) 
         {
             if( this.a1 <= 0 && this.aM > 0 ) //case [a]
             {
                 this.I[0] = (-this.c1/(4*this.l))*this.a1;
                 this.I[1] = 0; 
             }
             else if( this.a1 > 0 && this.aM >0 && this.a2 <= 0 ) //case [e]
             {
                 this.I[0] =0;
                 this.I[1]=(-this.c2/(4*this.l))*this.a2;
             }
             else if( this.a1 > 0 && this.aM < 0 ) //case [d]
             {
                 this.I[0] = (-this.c1/(4*this.l))*this.aM ; 
                 this.I[1] = (-this.c2/(4*this.l))*(this.a2 + (this.aM*this.d2)/(2*(this.cpo3-this.dM)));
             }
             else if( this.a1 <= 0 && this.a2 <= 0 ) //case [c]
             {
                 this.I[0]=(-this.c1/(4*this.l))*(this.a1 + (this.aM*this.d2)/(2*(this.dM-this.cpo1))); 
                 this.I[1]=(-this.c2/(4*this.l))*(this.a2 + (this.aM*this.d2)/(2*(this.cpo3-this.dM)));
             }
             else  //case [b] - a1 <=0 && aM <=0 && a2 > 0
             {
                this.I[0] = (-this.c1/(4*this.l))*(this.a1 + (this.aM*this.d2)/(2*(this.dM-this.cpo1)));
                this.I[0] = (-this.c2/(4*this.l))*this.aM ;
             }
         }
         else
         {
            this.I[0] = 0;
            this.I[1] = 0; 
         }
     }
     
     
     //update syringeal membrane areas due to syringeal & TL pressure (implements Zaccharelli, 2008 Ch. 4 & Appendix C)
     protected updateRestingAreas()
     {
         this.a01 = this.ptl*(this.a0Change/this.maxPtl) + this.a0min; 
         this.a02 = this.ptl*(this.a0Change/this.maxPtl) + this.a0min; 
     }
     
    //update the Q based on muscle tension. Q (quality factor) models ratio of energy stored to energy dissapated in a system, in this context combines the muscle pressure
    //& then modifies stiffness & mass values in the oscillation equation in updateX()
    protected updateQ()
    {
        this.Psum = this.ptl + this.pt; //update Psum first
        this.Q = this.Psum*( this.Qchange/this.maxPsum ) + this.Qmin; //now update Q
    }
    
    //changes Ps
    protected changePs(ps : number)
    {
        this.goalPs = ps; 
    }
    
    protected changePtl(ptl : number)
    {
        this.goalPtl = ptl; 
    }
    
    protected changePt(pt : number)
    {
        this.goalPt = pt; 
    }
    
    /*
    fun void updatePs()
    {
        goalPs - Ps => float diff; 
        (dPs + diff)*T*modPs => dPs ; 
        Ps + dPs => Ps;      
    }
    */
    
    //******a set of functions to change the user-controlled time-varying parameters. 
    //*****These are set to smooth the change over time, to prevent cracks and breaks in the sound
    public updatePs()
    {
        this.dPs = this.updateParamD(this.Ps, this.goalPs, this.dPs, this.modPs);
        this.Ps = this.updateParam(this.Ps, this.goalPs, this.dPs, this.modPs);
    }
    
    public updatePtl()
    {
        this.dPtl = this.updateParamD(this.ptl, this.goalPtl, this.dPtl, this.modPtl);
        this.ptl = this.updateParam(this.ptl, this.goalPtl, this.dPtl, this.modPtl);
    }
    
    public updatePt()
    {
        this.dPt = this.updateParamD(this.pt, this.goalPt, this.dPt, this.modPt);
        this.pt = this.updateParam(this.pt, this.goalPt, this.dPt, this.modPt);
    }
    
    protected updateParamD( param : number, paramGoal : number, derivative : number, modN : number )
    {
        let diff = paramGoal - param; 
        derivative = (derivative + diff)*this.T*modN ; 
        return derivative;   
    }

    
    protected updateParam( param : number, paramGoal : number, derivative : number, modN : number)
    {
        param = param + derivative; 
        return param;        
    }
    
    //Main processing function of the chugen (plug-in). Everything that does stuff is called from here.
    public tick(inSample : number) : number  //with trachea, inP is the input pressure from waveguide / tube / trachea modeling... 
    {
        //recover if inputP gets weird values....
        if(Number.isNaN(this.inputP))
        {
            this.inputP = 0; //stop overflow
            // <<<"**********************NAN********************** U: " +U>>>;
            // <<<"**********************NAN********************** dU: " + dU>>>;
            // <<<"**********************NAN********************** Ps: " + Ps>>>;
            // <<<"**********************NAN**********************">>>;
        }
        
        this.updateX();
        this.updateForce(); //update the Ps with the inputP here
        this.updateCollisions();
        this.updateURingDove(this.Ps - this.inputP); 
        this.updateRestingAreas();
        this.updateQ();
        
        //update time-varying & user-controlled parameters
        this.updatePs(); //implements a smoothing function
        this.updatePtl();
        this.updatePt(); 
        
        return this.dU; 
    }
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxDoveMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
