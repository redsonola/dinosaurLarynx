//Fletcher (1988) / Smyth (2002) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";
import './Complex.worklet'


// class BirdTracheaFilter extends Chugen
// {
//     1.0 => float a1;
//     1.0 => float b0;
//     0.0 => float lastOut; 
//     0.0 => float lastV; 
    
//     fun float tick(float in)
//     {
//         b0*in => float vin;
//         vin + lastV - a1*lastOut => float out;
//         out => lastOut; 
//         vin => lastV; 
//         return out; 
//     }     
// }

//Syrinx Membrane
const birdTracheaFilter =  /* javascript */`class ReflectionFilter
{
    protected a1 = 1.0;
    protected b0 = 1.0;
    protected lastOut = 0.0 ; 
    protected lastV = 0.0 ; 
    protected c = 0; //speed of sound
    protected T = 0; //sample period
    protected oT = 0;
    protected alpha = 0;
    protected wT = 0;

    //get some constants from the enclosing membrane class
    constructor(c : number, T : number)
    {
        this.c = c; 
        this.T = T; 
        this.a1 = 1.0;
        this.b0 = 1.0; 
        this.lastOut = 0; 
        this.lastV = 0;    
        this.oT = 0; 

        this.alpha = 0;
        this.wT = 0;
    }

    public tick(input : number) : number 
    {
        if(  Number.isNaN(this.lastOut) )
        {
            this.lastOut = 0;
        }
        if(  Number.isNaN(this.lastV) )
        {
            this.lastV = 0;
        }
        let vin = this.b0 * input;
        let out = vin + this.lastV - this.a1 * this.lastOut;
        this.lastOut = out; 
        this.lastV = vin; 
        
        return out; 
    }     

    public setParamsForReflectionFilter(a: number) : void
    {
        let ka = 1.8412; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
        this.wT = ka*(this.c/(a*2))*this.T; 
             
        //magnitude of -1/(1 + 2s) part of oT from Smyth, eq. 4.44
        let s = ka; //this is ka, so just the coefficient to sqrt(-1), s to match Smyth paper

        let numerator = new Complex(-1, 0);
        let denominator = new Complex(1, 2*s);
        let complexcHr_s =  numerator.divide(denominator);
        this.oT = Math.sqrt( complexcHr_s.re*complexcHr_s.re + complexcHr_s.im*complexcHr_s.im ); //magnitude of Hr(s)
    
        //( 1 + Math.cos(wT) - 2*oT*oT*Math.cos(wT) ) / ( 1 + Math.cos(wT) - 2*oT*oT ) => float alpha
        this.alpha = ( 1 + Math.cos(this.wT) - 2*this.oT*this.oT*Math.cos(this.wT) ) / ( 1 + Math.cos(this.wT) - 2*this.oT*this.oT ); //to determine a1 
        this.a1 = -this.alpha + Math.sqrt( this.alpha*this.alpha - 1 );
        this.b0 = (1 + this.a1 ) / 2;     
    }
   
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(birdTracheaFilter, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


