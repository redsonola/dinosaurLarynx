//import { getContext, type InputNode, type OutputNode } from "tone";

import "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./SyrinxMembraneSynthesis.worklet";
import "./SyrinxMembraneSynthesisElemansDoveBased.worklet";
import "./BirdTracheaFilter.worklet"
import "./tonejs_fixed/DelayLine.worklet";
import "./WallLoss.worklet";
import "./HPout.worklet";
import "./ScatteringJunction.worklet";
import "./LVMCoupler.worklet";

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

        this.FletcherSmyth = 0;
        this.ElemansZacharelli = 1;
        this.whichVocalModel = this.ElemansZacharelli; //default

        this.createMembrane(); //create the membrane

        this.lastSample = 0;
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 
        this.lastPressureSamp = 0; //for ElemansZacharelli -- hmm... not sure if I like how I'm handling this

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

        this.bronch1Delay1Pressure = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch1Delay2Pressure = new DelayLine(this.sampleRate, options.channelCount || 2);
        
        //hadrosaur values
        this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);
        

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilterPressure = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilterPressure.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTrachealSyrinx;
        this.membraneCount = 1; 
        this.setDelayTime( this.getPeriod() );

        //for smyth fletcher -- TODO-- change with the syrinx model
        //this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.

        this.max = 1; //for elemans zacharelli


        this.count = 0; //for outputting values at a lower rate


    }

    protected setSyrinxModel(which : number) : void
    {
        if( which != this.whichVocalModel )
        {
            this.whichVocalModel = which; 
            this.initFunc(true);
        }
    }

    protected createMembrane() : void
    {
        if( this.whichVocalModel == this.FletcherSmyth || this.whichVocalModel != this.ElemansZacharelli ) //if which is garbage, set to default
        {
            this.membrane = new SyrinxMembrane();
            this.membrane2 = new SyrinxMembrane();
        }
        else
        {
            this.membrane = new RingDoveSyrinx();
            this.membrane2 = new RingDoveSyrinx();
            this.lvmCoupler = new LVMCoupler(this.membrane); //for ElemansZacharelli

        }
    }

    protected initFunc(createNewMembrane : boolean = true) : void
    {
        if( createNewMembrane )
        {
            this.createMembrane(this.whichVocalModel);
        }

        this.lastSample = 0;
        this.lastPressureSamp = 0;       
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 

        this.delayTimeBronchi = 0; //delay of each of the bronchi sides
        this.delayTime = 0; //the trachea delay time

        //one for each way
        this.bronch1Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch1Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.bronch1Delay1Pressure = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch1Delay2Pressure = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.bronch2Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch2Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.tracheaDelay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.tracheaDelay2 = new DelayLine(this.sampleRate, this.channelCount || 2);
        
        //hadrosaur values
        if( this.whichVocalModel == this.FletcherSmyth )
            this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilterPressure = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilterPressure.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTracheobronchial;
        this.membraneCount = 1; 
        this.setDelayTime( this.getPeriod() );

        this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.


        this.count = 0; //for outputting values at a lower rate

        console.log("called"); 
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
        //c/(2*(L/100.0)) => float LFreq;

        let LFreq = this.membrane.c/(2*this.membrane.L/100);
        //let period = 0.5 / LFreq;
        let period = (1 / LFreq) - (1/this.membrane.SRATE) ;
        return period; //in seconds 
    }

    protected hadrosaurInit() : void
    {
        //in cm
        this.membrane.a = 4.5; 
        this.membrane.h = 4.5; 
        this.membrane.L = 116; //test
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
            name: "Ps",
            defaultValue: 0,
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        },
        {
            name: "ptl",
            defaultValue: 0,
            minValue: 0,
            maxValue: 40,
            automationRate: "k-rate"
        }, 
        {
            name: "pt", //currently not implemented
            defaultValue: 0,
            minValue: -2,
            maxValue: 2,
            automationRate: "k-rate"
        }, 
        {
            name: "inputMusclePressure", //currently not implemented
            defaultValue: 0,
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        }, 
        {
            name: "syrinxModel", //currently not implemented
            defaultValue: 1, //0 for FletcherSmyth, 1 for ElemansZacharelli, default is Elemans for now
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        }, 
        {
            name: "membraneCount",
            defaultValue: 1,
            minValue: 1,
            maxValue: 2,
            automationRate: "k-rate"
        } 
        ];
    } 

    generate(input:any, channel:any, parameters:any) {
        return this.generateFunction(input, channel, parameters);  //default is Tracheobronchial for now
    }

    //single wave guide -- take in a syrinx membrane & resonate through a trachea
    waveguideSingleMembrane( inSample: number, delay1: any, delay2: any, tracheaFilter:any, lastSamp:number, channel: any, parameters: any ) : number
    {

        //RingDoveSyrinxLTM ltm => delay => lp => blackhole;
        //lp => wa => delay => LPF lpf => Dyno limiter => dac;

        //********1st delayLine => tracheaFilter => flip => last sample  *********
        let curOut = this.delayLineGenerate(inSample, channel, parameters, delay1, this.delayTime);
        lastSamp = tracheaFilter.tick(curOut); //low-pass filter
        //lastSamp = lastSamp * -1; //flip -- do not flip for closed mouth

        //********2nd delayLine, going back *********
        let fout = this.wallLoss.tick(lastSamp); //was lastSamp, but that can't be right
        fout = this.delayLineGenerate(fout, channel, parameters, delay2, this.delayTime);

        this.count++;
        if(this.count >50)
        {
            console.log(this.delayTime);
            this.count = 0;
        }
        return fout;
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

        if(  Number.isNaN(this.lastPressureSamp) )
        {
             this.lastPressureSamp = 0;
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
        if ( this.whichVocalModel == this.FletcherSmyth )
        {
            this.membrane.changePG(parameters.pG);
            this.membrane.changeTension(parameters.tension);
        }
        else if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            //note: using the built-in 0-1 mapping membrane synthesis side for now.
            this.membrane.updateInputPressure(parameters.Ps);
            this.membrane.updateInputMusclePressure(parameters.inputMusclePressure);
            // this.membrane.updateInputMusclePressure(0.0125); //testing - set at 0.5 ptl
            // this.membrane.updateInputPressure(0.5); //testing - set at 0.5*0.05 ps
        }

        let pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 

        //travel through the trachea tubes
        let fout = this.waveguideSingleMembrane( pOut, this.bronch1Delay1, this.bronch1Delay2, this.tracheaFilter, this.lastSample, channel, parameters );
        this.lastSample = fout;
        
        //******** Add delay lines ==> High Pass Filter => out  *********
        //fout = this.hpOut.tick(fout); -- no high pass for now

        let reflectedPressure = 0;
        if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            reflectedPressure = this.waveguideSingleMembrane( this.lvmCoupler.last()+this.lastPressureSamp, this.bronch1Delay1Pressure, this.bronch1Delay2Pressure, this.tracheaFilterPressure, this.lastPressureSamp, channel, parameters );
            this.lvmCoupler.tick(reflectedPressure);
            this.lastPressureSamp = reflectedPressure;
            let blackhole = this.delayLineGenerate(reflectedPressure, channel, parameters, this.bronch1Delay1Pressure, this.delayTime);

        }
        //console.log("reflectedPressure: " + reflectedPressure);

        //****** simple scaling into more audio-like values, sigh  *********
        //fout = fout/this.max;  

        //test to see if I need a limiter
        // this.count++;
        // if( this.max < fout )
        // {
        //     console.log("max: "+ this.max);
        // }
        // this.max = Math.max(this.max, fout); 

        // if(this.count >50)
        // {
        //     this.count = 0;
        // }    

    
        //limit output to -1 to 1
        if (Math.abs(fout) > 1.0)
        {
            this.max = Math.max(this.max, Math.abs(fout));
            fout = fout/this.max;
            //this.count++;
        }

        // this.count++;
        // if(this.count > 100)
        // {
        //     this.count=0;
        //     console.log("a1: " + this.membrane.a1 + " a2: " + this.membrane.a2 + " a01: " + this.membrane.a01 + " a02: " + this.membrane.a02 + " ptl: " + this.membrane.ptl + " Pt: " + this.membrane.pt);// + "x01: " + this.membrane.x01 + " x02: " + this.membrane.x02);
        //     console.log(" cpo1: " + this.membrane.cpo1 + " cpo2: " + this.membrane.cpo2 + " cpo3: " + this.membrane.cpo3);
        //     console.log( "r: " + this.membrane.r + " k: " + this.membrane.k +" kc: " + this.membrane.kc + " d2x1: " + this.membrane.d2x[0] + " d2x2: " + this.membrane.d2x[1] + " timestep: " + this.membrane.timeStep );
        //     console.log( "inputP: " + this.membrane.inputP +" Ps: " + this.membrane.Ps +" F1: " + this.membrane.F[0] + " F2: " + this.membrane.F[1] + " d1: " + this.membrane.d1 + " d2: " + this.membrane.d2 +" d3: " + this.membrane.d3 + " dM: " + this.membrane.dM);
        //     console.log( "I1: " + this.membrane.I[0] + " I2: " + this.membrane.I[1]);
        //     console.log( "whichForce1: " + this.membrane.whichForce1 + " x1: " + this.membrane.x[0] + " x2: " + this.membrane.x[1] + " dx1: " + this.membrane.dx[0] + " dx2: " + this.membrane.dx[1]  );
        // }
        // console.log("ptl: " + this.membrane.ptl );
        // console.log("pt: " + this.membrane.pt );

    
        //****** output w/high pass *********      
        return fout;
    }

    //2 membranes, as in passerines
    generateTracheobronchial(input:any, channel:any, parameters:any) {

        //**** syrinx membrane ******
        //this.setSyrinxModel(parameters.syrinxModel);
        if ( this.whichVocalModel == this.FletcherSmyth )
        {
            this.membrane.changePG(parameters.pG);
            this.membrane.changeTension(parameters.tension);

            this.membrane2.changePG(parameters.pG);
            this.membrane2.changeTension(parameters.tension);
        }
        else if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            //note: using the built-in 0-1 mapping membrane synthesis side for now.
            this.membrane.updateInputPressure(parameters.Ps);
            this.membrane.updateInputMusclePressure(parameters.inputMusclePressure);

            this.membrane2.updateInputPressure(parameters.Ps);
            this.membrane2.updateInputMusclePressure(parameters.inputMusclePressure);
        }       

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
        if( this.whichVocalModel == this.FletcherSmyth )
        {
            fout = fout/(this.max*2);   
        } 
        else
        {
            if (Math.abs(fout) > 1.0)
            {
                this.max = Math.max(this.max, fout);
                fout = fout/this.max;
                console.log("max: " + this.max);
            }
        }
        
        if( Number.isNaN(fout) )
        { 
            console.log(" NaN detected.... relaunching ");
            this.initFunc();
            fout = this.lastSample;
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

