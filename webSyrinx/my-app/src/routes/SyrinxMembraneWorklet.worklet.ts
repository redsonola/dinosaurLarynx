//import { getContext, type InputNode, type OutputNode } from "tone";

import "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./SyrinxMembraneSynthesis.worklet";
import "./BirdTracheaFilter.worklet"
import "./tonejs_fixed/DelayLine.worklet";


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
    
    protected lastSample : number  0; //last sample from the output

    constructor(options : any) {
        super(options);
        this.membrane = new SyrinxMembrane();


        this.delayLine = new DelayLine(this.sampleRate, options.channelCount || 2);
        
        this.hadrosaurInit();
        this.tracheaFilter = new BirdTracheaFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        //the combfilter for the waveguide
        let L : number = 116; //in cm 
        let c : number = this.membrane.c; // in m/s
        let LFreq = c/(2*L);
        let period : number = (0.5) / (LFreq) ; //in seconds

        this.delayTime = period; 
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

    //NOTE: Web Audio API does NOT allow cycles except when there is a delay, which introduces at least 1 buffer of audio delay (128 samples) 
    //which is not fine enough granularity for the waveguides. So all processing for the syrinx is here.
    //I will refactor this later.
    //my GOD! what a #$%^&*&^%^&*ing pain.
    generate(input:any, channel:any, parameters:any) {

        //implementing this chain
        //membrane.chain(comb, lp, flip, p1, Tone.Destination);
        //p1.connect(membrane);
        //p1.connect(comb);

        //**** syrinx membrane ******
        //this.membrane.changeTension(25000000);
        this.membrane.changePG(parameters.pG);
        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 

        //********1st delayLine*********
        this.lastSample = this.delayLineGenerate(pOut+this.lastSample, channel, parameters);
        this.lastSample = this.tracheaFilter.tick(this.lastSample); 
        this.lastSample = this.lastSample * -1;

        return this.lastSample;
    }

    //this is the delayLine generate -- note: I will probably have to have multiple delay lines
    //this function altered slightly from tonejs FeedbackCombFilter
    protected delayLineGenerate(input, channel, parameters) : number {
        const delayedSample = this.delayLine.get(channel, this.delayTime * this.sampleRate);
        this.delayLine.push(channel, input);
        return delayedSample;
    }
}

`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
registerProcessor(workletName, outputText);

