//Courtney Brown -- Couples the LVM to the vocal tract by returning the pressure value at the end of the trachea
//to the ring dove syrinx-based membrane model from Elemans/Zaccarelli
//Note: Another way would be to actually use the pressure outputs for evertything instead of dU for audio out
//however, I need to do more research before deciding this -- dU output is the standard for 2-mass models
//so doing this to keep apples as apples, oranges as oranges so to speak
//Translated from Chuck code I originally wrote (courtney Brown) to Javascript Web Audio

import { addToWorklet } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";
import './Complex.worklet'
import "./SyrinxMembraneSynthesisElemansDoveBased.worklet"; 


//Syrinx Membrane
const lvmC =  /* javascript */`class LVMCoupler
{
    protected p1 : number ; 
    protected lvm : any;

    constructor(l : any)
    {
        this.lvm = l; 
        this.p1 = 0;
    }
    
    public tick(input : number) : number
    {
        //-- this is seconds, but I want to xlate to samples
        //does this make sense? look at parameters for airflow, too
        
        //prevent blowups
        if (input > 3.0)
        {
            input = 0;
        }
        
        this.p1 = this.lvm.z0/this.lvm.SRATE * this.lvm.U; //outgoing pressure value into the vocal tract
        
        this.lvm.inputP = input*2 + this.p1;
        return this.p1; //output pressure  
    }
    
    public last()
    {
        return this.p1; 
    }
}`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(lvmC, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
addToWorklet(outputText);
//outputText = "START!!!! \n" + outputText + "END!!!!\n";
//console.log(outputText);


