//import { getContext, type InputNode, type OutputNode } from "tone";

import "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./SyrinxMembraneSynthesis.worklet";

import { registerProcessor } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";

export const workletName = "syrinx-membrane";

//Create an audio worklet 
//Need to do this:
//https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode

//Using the following as a model
//https://github.com/Tonejs/Tone.js/blob/08df7ad68cb9ed4c88d697f2230e3864ca15d206/Tone/component/filter/FeedbackCombFilter.worklet.ts
export const syrinxMembraneGenerator = /* typescript */`class SyrinxMembraneGenerator extends SingleIOProcessor {
    constructor(options : any) {
        super(options);
        this.membrane = new SyrinxMembrane();
        this.hadrosaurInit();
    }

    protected hadrosaurInit() : void
    {
        //in cm
        this.membrane.a = 4.5; 
        this.membrane.h = 4.5; 
        this.membrane.L = 116; //dummy
        this.membrane.d = 5.0; 

        //in various
        this.membrane.modT = 10000.0; 
        this.membrane.modPG = 80;
   
        this.membrane.initTension(); 
        this.membrane.initZ0;
    }

    static get parameterDescriptors() {
        return [{
            name: "pG",
            defaultValue: 0,
            minValue: 0,
            maxValue: 250000,
            automationRate: "k-rate"
        }];
    }

    generate(input:any, channel:any, parameters:any) {
        //this.membrane.changeTension(25000000);
        this.membrane.changePG(parameters.pG);
        const samp = this.membrane.tick(input); //the syrinx membrane  //Math.random() * 2 - 1; 
        return samp;
    }
}

`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
registerProcessor(workletName, outputText);

