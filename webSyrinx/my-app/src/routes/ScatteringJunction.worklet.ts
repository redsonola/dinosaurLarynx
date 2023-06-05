//Fletcher (1988) / Smyth (2002) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";

//scattering junction, from Smyth 2004
const scatteringJunction =  /* javascript */`class ScatteringJunction 
{
    constructor(impedence : number)
    {
        this.z0 = 0;
        this.tubeZ = 0;
        this.zSum = 0; 
        this.updateZ0(impedence);
    }
    
    public updateZ0(impedence : number) : void
    {
        this.z0 = impedence; 
        this.zSum = (1.0/this.z0 + 1.0/this.z0 + 1.0/this.z0);         
        this.tubeZ = 1.0/this.z0;
    }
    
    public scatter(bronch1 : number, bronch2 : number, trachea : number) : any
    { 
        let bronch1Out : number = 0; 
        let bronch2Out : number = 0; 
        let tracheaOut : number = 0; 

        let add = bronch1*this.tubeZ + bronch2*this.tubeZ +  trachea*this.tubeZ;
        add *= 2; 

        //assume they have the same tube radius for now
        let pJ = add / this.zSum;
    
        return {b1: pJ-bronch1, b2: pJ-bronch2, trach: pJ-trachea};
    }
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(scatteringJunction, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


