//Fletcher (1988) / Smyth (2002) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";
import './Complex.worklet'



//Syrinx Membrane
const hPFilterOut =  /* javascript */`class HPFilter
{
    protected a1 : number = 1; 
    protected b0 : number = 1; 
    protected lastOut : number = 0; 
    protected lastV : number = 0; 

    constructor(a1:number, b0:number)
    {
        this.a1 = a1; 
        this.b0 = b0;
        this.lastOut = 0; 
        this.lastV = 0; 

    }
    
    public tick(input : number) : number
    {
        let vin = input - this.b0*input;
        let output = vin + (this.a1-this.b0)*this.lastV - this.a1*this.lastOut;
        this.lastOut = output; 
        this.lastV = vin; 
        return output; 
    }     
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(hPFilterOut, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


