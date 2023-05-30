//Fletcher (1988) / Smyth (2002) Syrinx Computational Model Syrinx Membrane
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";


//complex numbers class as import during audio worklet
//not worth it, so making this helper...
const complexClass =  /* javascript */`
class Complex
{
    public re : number = 0; 
    public im : number = 0;

    //get some constants from the enclosing membrane class
    constructor(re : number, im : number)
    {
        this.re = re; 
        this.im = im; 
    }

    public divide( denom: Complex ) : Complex
    {
        let resReal = 0;
        let reIm = 0;

        let a = this.re;
        let b = this.im; 
        let c = denom.re;
        let d = denom.im; 

        let res = new Complex(0,0);
        res.re = (a*c + b*d)/(c*c + d*d);
        res.im = (b*c - a*d)/(c*c + d*d);

        return res; 
    }
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(complexClass, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


