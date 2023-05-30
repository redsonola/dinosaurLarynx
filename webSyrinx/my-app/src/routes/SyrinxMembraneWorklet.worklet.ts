//import { getContext, type InputNode, type OutputNode } from "tone";

import "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./SyrinxMembraneSynthesis.worklet";
import "./BirdTracheaFilter.worklet"
import "./tonejs_fixed/DelayLine.worklet";
import "./WallLoss.worklet"


import { registerProcessor } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";

export const workletName = "syrinx-membrane";

//Create an audio worklet 
//Need to do this:
//https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode

//Using the following as a model
//https://github.com/Tonejs/Tone.js/blob/08df7ad68cb9ed4c88d697f2230e3864ca15d206/Tone/component/filter/FeedbackCombFilter.worklet.ts
export const syrinxMembraneGenerator = /* typescript */ `class SyrinxMembraneGenerator extends SingleIOProcessor {
    
    protected lastSample : number = 0; //last sample from the output

    constructor(options : any) {
        super(options);
        this.membrane = new SyrinxMembrane();
        this.lastSample = 0; 

        //one for each way
        this.delayLine1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.delayLine2 = new DelayLine(this.sampleRate, options.channelCount || 2);
        
        this.hadrosaurInit();
        this.tracheaFilter = new BirdTracheaFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        //the delay of comb filter for the waveguide
        this.delayTime = this.getPeriod();

        let f1 = this.membrane.wFreq[0]/(2*Math.PI);
        let f2 = this.membrane.wFreq[1]/(2*Math.PI);
        
        //console.log(f1);
        //console.log(f2);
        //console.log(this.membrane.curT);

        this.max = 300;

        this.count = 0;

    }

    //the combfilter for the waveguide
    protected getPeriod() : number
    {
        let LFreq = this.membrane.c/(2*this.membrane.L);
        let period = 0.5 / LFreq;
        console.log(period);
        return period; //in seconds 
    }

    protected hadrosaurInit() : void
    {
        //in cm
        this.membrane.a = 4.5; 
        this.membrane.h = 4.5; 
        this.membrane.L = 116; //dummy
        this.membrane.d = 5; 

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
        },
        {
            name: "tension",
            defaultValue: 2000,
            minValue: 0,
            maxValue: 168397230,
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

        //from membrane to trachea and part way back
        //SyrinxMembrane mem => DelayA delay => lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning
        
        //the feedback from trachea reflection
        //Gain p1; 
        //wa => p1; 
        //mem => p1; 
        ////p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 => delay; 

        //**** syrinx membrane ******
        this.membrane.changePG(parameters.pG);
        this.membrane.changeTension(parameters.tension);

        this.count++;
        if(this.count >50)
        {
            console.log(this.membrane.pG + ", " + parameters.tension);
            this.count = 0;
        }
        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 

        //********1st delayLine => tracheaFilter => flip => last sample  *********
        let curOut = this.delayLineGenerate(pOut+this.lastSample, channel, parameters, this.delayLine1);
        this.lastSample = this.tracheaFilter.tick(curOut); //low-pass filter
        this.lastSample = this.lastSample * -1; //flip

        //********2nd delayLine, going back *********
        this.lastSample = this.delayLineGenerate(this.lastSample, channel, parameters, this.delayLine2);
        this.lastSample = this.wallLoss.tick(this.lastSample); 

        //******** Add delay lines ==> High Pass Filter => out  *********
        curOut = curOut + this.lastSample;
        
        //****** simple limiting, sigh - look up a better way *********
        this.max = Math.max(this.max, curOut);
        curOut = curOut/this.max; 

        //curOut = this.hpOut.tick(curOut);

        return curOut;
    }

    //this is the delayLine generate -- note: I will probably have to have multiple delay lines
    //this function altered slightly from tonejs FeedbackCombFilter
    protected delayLineGenerate(input, channel, parameters, delayLine) : number {
        const delayedSample = delayLine.get(channel, this.delayTime * this.sampleRate);
        delayLine.push(channel, input);
        return delayedSample;
    }
}

`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
registerProcessor(workletName, outputText);

