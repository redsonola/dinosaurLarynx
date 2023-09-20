//import { getContext, type InputNode, type OutputNode } from "tone";

import "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./SyrinxMembraneSynthesis.worklet";
import "./BirdTracheaFilter.worklet"
import "./tonejs_fixed/DelayLine.worklet";
import "./WallLoss.worklet";
import "./HPout.worklet";
import "./ScatteringJunction.worklet";

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
        this.membrane2 = new SyrinxMembrane(); 

        this.lastSample = 0;
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 

        this.delayTimeBronchi = 0; //delay of each of the bronchi sides
        this.delayTime = 0; //the trachea delay time

        this.channelCount = options.channelCount;

        //one for each way
        this.bronch1Delay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch1Delay2 = new DelayLine(this.sampleRate, options.channelCount || 2);

        this.bronch2Delay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch2Delay2 = new DelayLine(this.sampleRate, options.channelCount || 2);

        this.tracheaDelay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.tracheaDelay2 = new DelayLine(this.sampleRate, options.channelCount || 2);
        
        //hadrosaur values
        this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTracheobronchial;
        this.membraneCount = 2; 
        this.setDelayTime( this.getPeriod() );

        this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.


        this.count = 0; //for outputting values at a lower rate


    }

    //setMembraneCount
    void setMembraneCount(count : number)
    {
        this.membraneCount = count;
        if( membraneCount <= 1 )
        {
            this.generateFunction = this.generateTrachealSyrinx;
            this.setDelayTime( this.getPeriod() );
        }
        else
        {
            this.generateFunction = this.generateTracheobronchial;
            this.setDelayTime( this.getPeriod() );
        }
    }

    protected initFunc()
    {
        console.log("here"); 

        this.membrane = new SyrinxMembrane();
        this.membrane2 = new SyrinxMembrane(); 

        this.lastSample = 0;
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 

        this.delayTimeBronchi = 0; //delay of each of the bronchi sides
        this.delayTime = 0; //the trachea delay time

        //one for each way
        this.bronch1Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch1Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.bronch2Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch2Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.tracheaDelay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.tracheaDelay2 = new DelayLine(this.sampleRate, this.channelCount || 2);
        
        //hadrosaur values
        this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTracheobronchial;
        this.membraneCount = 2; 
        this.setDelayTime( this.getPeriod() );

        this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.


        this.count = 0; //for outputting values at a lower rate
    }

    //set delay time
    protected setDelayTime(period : number)
    {
        this.delayTime = period; 

        //values from Smyth 2002, in mm
        //large bird - bronchus to trachea - 30/35.6 -- taking the large bird radius (still a small bird)
        //medium bird - bronchus to trachea - 14/23
        //small bird - bronchus to trachea - 5/17.1

        //ok just testing here
        if(this.membraneCount >= 2)
        {
            //let's say the MTM bronchi to the trachea length is 1/15 of the trachea 
            //I got this by looking at diagrams
            this.delayTimeBronchi = period*(30/35.6);  
        }
    }

    //period of the comb filter for the waveguide
    protected getPeriod() : number
    {
        let LFreq = this.membrane.c/(2*this.membrane.L);
        let period = 0.5 / LFreq;
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

        //repeat, maybe I should arrayify...
        this.membrane2.a = 4.5; 
        this.membrane2.h = 4.5; 
        this.membrane2.L = 116; //dummy
        this.membrane2.d = 5; 

        //in various
        this.membrane2.modT = 10000.0; 
        this.membrane2.modPG = 80;
   
        this.membrane2.initTension(); 
        this.membrane2.initZ0;
    }

    static get parameterDescriptors() {
        return [{
            name: "pG",
            defaultValue: 0,
            minValue: 0,
            maxValue: 2500000,
            automationRate: "k-rate"
        },
        {
            name: "tension",
            defaultValue: 2000,
            minValue: 0,
            maxValue: 168397230,
            automationRate: "k-rate"
        }, 
        {
            name: "membraneCount",
            defaultValue: 2,
            minValue: 1,
            maxValue: 2,
            automationRate: "k-rate"
        },        
        {
            name: "rightTension",
            defaultValue: 2000,
            minValue: 0,
            maxValue: 168397230,
            automationRate: "k-rate"
        }];
    }

    //default is Tracheobronchial for now --  change to TrachealSyrinx by changing membrane count
    generate(input:any, channel:any, parameters:any) {
        
        /***** change membrane count if needed *****/
        this.setMembraneCount(parameters.membraneCount);

        return this.generateFunction(input, channel, parameters);  
    }

    //NOTE: Web Audio API does NOT allow cycles except when there is a delay, which introduces at least 1 buffer of audio delay (128 samples) 
    //which is not fine enough granularity for the waveguides. So all processing for the syrinx is here.
    //I will refactor this later.
    //my GOD! what a #$%^&*&^%^&*ing pain.
    generateTrachealSyrinx(input:any, channel:any, parameters:any) {

        if(  Number.isNaN(this.lastSample) )
        {
            this.lastSample = 0;
        }
         
        if(  Number.isNaN(this.lastSample2) )
        {
            this.lastSample2 = 0;
        }

        if(  Number.isNaN(this.lastTracheaSample) )
        {
            this.lastTracheaSample = 0;
        }

        //*****implementing this chuck code.....

        //from membrane to trachea and part way back
        //SyrinxMembrane mem => DelayA delay => lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning
        
        //the feedback from trachea reflection
        //Gain p1; 
        //wa => p1; 
        //mem => p1; 
        ////p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 => delay; 
        //************

        //**** syrinx membrane ******
        this.membrane.changePG(parameters.pG);
        this.membrane.changeTension(parameters.tension);

        // this.count++;
        // if(this.count >50)
        // {
        //     console.log(this.membrane.pG + ", " + parameters.tension);
        //     this.count = 0;
        // }
        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 

        //********1st delayLine => tracheaFilter => flip => last sample  *********
        let curOut = this.delayLineGenerate(pOut+this.lastSample, channel, parameters, this.bronch1Delay1, this.delayTime);
        this.lastSample = this.tracheaFilter.tick(curOut); //low-pass filter
        this.lastSample = this.lastSample * -1; //flip

        //********2nd delayLine, going back *********
        this.lastSample = this.delayLineGenerate(this.lastSample, channel, parameters, this.bronch1Delay2, this.delayTime);
        this.lastSample = this.wallLoss.tick(this.lastSample); 

        //******** Add delay lines ==> High Pass Filter => out  *********
        curOut = curOut + this.lastSample;
        let fout = this.hpOut.tick(curOut);

        //****** simple scaling into more audio-like values, sigh  *********
        fout = fout/this.max;  

        //test to see if I need a limiter
        this.count++;
        if(this.count >50)
        {
            // console.log(this.membrane.pG + ", " + parameters.tension);
            //console.log("max: "+ this.max);

            this.count = 0;
        }        

        //****** output w/high pass *********      

        return fout;
    }

    //2 membranes, as in passerines
    generateTracheobronchial(input:any, channel:any, parameters:any) {
        
        //**** syrinx membrane ******
        this.membrane.changePG(parameters.pG);
        this.membrane.changeTension(parameters.tension);

        this.membrane2.changePG(parameters.pG);
        this.membrane2.changeTension(parameters.rightTension);

        // this.count++;
        // if(this.count >50)
        // {
        //     console.log(this.membrane.pG + ", " + parameters.tension);
        //     this.count = 0;
        // }

        //******** Sound is generated and travels up each bronchi *********
        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 
        let curOut = this.delayLineGenerate(pOut+this.lastSample, channel, parameters, this.bronch1Delay1, this.delayTimeBronchi);
        this.lastSample = this.bronch1Filter.tick(curOut); //low-pass filter
        this.lastSample = this.lastSample * -1; //flip

        const pOut2 = this.membrane2.tick(this.lastSample2); //the syrinx membrane  //Math.random() * 2 - 1; 
        let curOut2 = this.delayLineGenerate(pOut2+this.lastSample2, channel, parameters, this.bronch2Delay1, this.delayTimeBronchi);
        this.lastSample2 = this.bronch2Filter.tick(curOut2); //low-pass filter
        this.lastSample2 = this.lastSample2 * -1; //flip 

        //******** Sound encounters Junction *********
        let scatterOut = this.scatteringJunction.scatter(curOut, curOut2, this.lastTracheaSample); 

        //******** Sound travels through trachea *********
        let trachOut = this.delayLineGenerate(scatterOut.trach + this.lastTracheaSample, channel, parameters, this.tracheaDelay1, this.delayTime);
        this.lastTracheaSample = this.tracheaFilter.tick(trachOut); //low-pass filter
        this.lastTracheaSample = this.lastTracheaSample * -1; //flip 

        //******** Sound is reflected from bronchi & trachea *********
        this.lastSample = this.delayLineGenerate(scatterOut.b1, channel, parameters, this.bronch1Delay2, this.delayTimeBronchi);
        this.lastSample = this.wallLoss.tick(this.lastSample); 

        this.lastSample2 = this.delayLineGenerate(scatterOut.b2, channel, parameters, this.bronch2Delay2, this.delayTimeBronchi);
        this.lastSample2 = this.wallLoss.tick(this.lastSample2); 

        this.lastTracheaSample = this.delayLineGenerate(this.lastTracheaSample, channel, parameters, this.tracheaDelay2, this.delayTime);
        //this.lastTracheaSample = this.wallLoss.tick(this.lastTracheaSample); 

        //******** Add delay lines ==> High Pass Filter => out  *********
        trachOut = trachOut + this.lastTracheaSample;
        let fout = this.hpOut.tick(trachOut);
        
        //****** simple scaling into more audio-like values, sigh  *********
        fout = fout/(this.max*2);    
        
        if( Number.isNaN(fout) )
        { 
            console.log(" NaN detected.... relaunching ");
            this.initFunc();
        }

        return fout;
    }


    //this is the delayLine generate -- note: I will probably have to have multiple delay lines
    //this function altered slightly from tonejs FeedbackCombFilter
    protected delayLineGenerate(input, channel, parameters, delayLine, delayTime) : number {
        const delayedSample = delayLine.get(channel, delayTime * this.sampleRate);
        delayLine.push(channel, input);
        return delayedSample;
    }
}

`;

//compile the typescript then spit out the javascript so I don't have to tediously make this code backwards compatible
let {outputText} = ts.transpileModule(syrinxMembraneGenerator, { compilerOptions: { module: ts.ModuleKind.None, removeComments: true, target: ScriptTarget.ESNext }});
registerProcessor(workletName, outputText);

