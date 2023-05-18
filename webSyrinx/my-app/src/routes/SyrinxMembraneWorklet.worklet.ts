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
    }

    static get parameterDescriptors() {
        return [{
            name: "delayTime",
            defaultValue: 0.1,
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        }, {
            name: "feedback",
            defaultValue: 0.5,
            minValue: 0,
            maxValue: 0.9999,
            automationRate: "k-rate"
        }];
    }

    generate(input:any, channel:any, parameters:any) {
        const samp = this.membrane.tick(input); //the syrinx membrane
        return samp;
    }
}

`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
registerProcessor(workletName, outputText);

