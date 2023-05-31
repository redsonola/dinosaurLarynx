//Courtney Brown 2023
//Implements a dinosaur syrinx
//This is a work in progress.
//Eventual goal is website + API based on tonejs.
//First goal is exhibition June 2023, sooo.

import * as Tone from 'tone';
import { Gain, optionsFromArguments } from 'tone';
import type { Time } from 'tone';
import { Effect, type EffectOptions } from 'tone/build/esm/effect/Effect';
import { ToneAudioWorklet, type ToneAudioWorkletOptions } from "./tonejs_fixed/ToneAudioWorklet";
import { FeedbackCombFilter } from "./tonejs_fixed/FeedbackCombFilter";
import { workletName } from "./SyrinxMembraneWorklet.worklet";
import { connectSeries } from "tone/build/esm/core/context/ToneAudioNode";
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';
import { singleIOProcess } from './tonejs_fixed/SingleIOProcessor.worklet';
import { addToWorklet } from './tonejs_fixed/WorkletGlobalScope';
import { Delay } from "tone/build/esm/core/context/Delay";
import { Param } from "tone/build/esm/core/context/Param";
import type { NormalRange, Positive } from "tone/build/esm/core/type/Units";
import { readOnly } from "tone/build/esm/core/util/Interface";
import { CombFilterEffect } from './CombFilter'

//# sourceMappingURL=ToneAudioWorklet.js.map

// import { Monophonic, type MonophonicOptions } from 'tone/build/esm/instrument/Monophonic';
//import { Source, type SourceOptions } from 'tone/tone/source/Source';

//mediapipe face-tracking
//NOTE: https://codepen.io/mediapipe-preview/pen/OJBVQJm

//Need to do this:
//https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode
//https://github.com/Tonejs/Tone.js/issues/712

//TODO: get this from audio options or something
var SAMPLERATE = 44100;
var CHANNEL_COUNT = 2;

export interface MembraneOptions extends EffectOptions {
	pG: Positive;
    tension: Positive; 
}
export class SyrinxMembraneFS extends Effect<MembraneOptions> {

	readonly name: string = "SyrinxMembrane";

	/**
	 * pG - air pressure in air sac
	 * @min 0
	 * @max 25000000
	 */
	readonly pG: Param<"positive">;

    /**
	 * tension 
	 * @min 0
	 * @max 
	 */
    readonly tension: Param<"positive">;


	/**
	 * The node which does the bit crushing effect. Runs in an AudioWorklet when possible.
	 */
	private _membraneWorklet: FletcherSmythSyrinxMembraneWorklet;

	constructor(pG?: Positive, tension?: Positive);
	constructor(options?: Partial<MembraneWorkletOptions>);
	constructor() {
		super(optionsFromArguments(SyrinxMembraneFS.getDefaults(), arguments, ["pG", "tension"]));
		const options = optionsFromArguments(SyrinxMembraneFS.getDefaults(), arguments, ["pG", "tension"]);

		this._membraneWorklet = new FletcherSmythSyrinxMembraneWorklet({
			context: this.context,
			pG: options.pG,
            tension: options.tension
		});
		// connect it up
		this.connectEffect(this._membraneWorklet);

		this.pG = this._membraneWorklet.pG;
        this.tension = this._membraneWorklet.tension; 
	}

	static getDefaults(): MembraneOptions {
		return Object.assign(Effect.getDefaults(), {
			pG: 0.0, 
            tension: 2000 
		});
	}

	dispose(): this {
		super.dispose();
		this._membraneWorklet.dispose();
		return this;
	}
}

interface MembraneWorkletOptions extends ToneAudioWorkletOptions {
	pG: number;
    tension: number;
}

//create the Syrinx Membrane Effect -- it has to be an effect with a source, as the membrane requires an input 
//as well
export class FletcherSmythSyrinxMembraneWorklet extends ToneAudioWorklet<MembraneWorkletOptions> 
{
    readonly name: string = "FletcherSmythSyrinxMembrane";
    
    readonly input: Gain;
	readonly output: Gain;

    /**
	 * The amount of delay of the comb filter.
	 */
	readonly pG: Param<"positive">;
    readonly tension: Param<"positive">;


	constructor(pG?: Positive, tension?: Positive);
	constructor(options?: RecursivePartial<MembraneWorkletOptions>);
	constructor() {
        addToWorklet(singleIOProcess);
		super(optionsFromArguments(FletcherSmythSyrinxMembraneWorklet.getDefaults(), arguments));
		const options = optionsFromArguments(FletcherSmythSyrinxMembraneWorklet.getDefaults(), arguments);

		this.input = new Gain({ context: this.context });
		this.output = new Gain({ context: this.context });

        this.pG = new Param<"positive">({
            context: this.context,
            value: options.pG,
            units: "positive",
            minValue: 0,
            maxValue: 25000000,
            param: this._dummyParam,
            swappable: true,
        });

        this.tension = new Param<"positive">({
            context: this.context,
            value: options.pG,
            units: "positive",
            minValue: 0,
            maxValue: 168397230,
            param: this._dummyParam,
            swappable: true,
        });
	}

    static getDefaults(): MembraneWorkletOptions {
		return Object.assign(ToneAudioWorklet.getDefaults(), {
			pG: 5.0,
            tension: 2000
		});
	}

    protected _audioWorkletName(): string {
		return workletName;
	}   

    onReady(node: AudioWorkletNode) {
		connectSeries(this.input, node, this.output);
        const pG = node.parameters.get("pG") as AudioParam;
		this.pG.setParam(pG);
        const tension = node.parameters.get("tension") as AudioParam;
		this.tension.setParam(tension);
	}

    dispose(): this {
		super.dispose();
		this.input.dispose();
		this.output.dispose();
        this.pG.dispose(); 
        this.tension.dispose(); 
		return this;
	}
} 

//-------------------------------------------------------------------------------------
//find wall loss
//Using a lumped loss scaler value for wall loss. TODO: implement more elegant filter for this, but so far, it works, so after everything else works.
class WallLossAttenuation //tuned to dino
{
    protected L = 116.0; //in cm --divided by 2 since it is taken at the end of each delay, instead of at the end of the waveguide
    private c = 34740; // in m/s
    protected freq = this.c/(2*this.L);
    protected w  = this.wFromFreq(this.freq);   
    //150.0*2.0*pi => float w;  
    
    protected a = 0.35; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
                     //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    protected propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff(); //theta in Fletcher1988 p466
    protected wallLossCoeff = this.calcWallLossCoeff(); //beta in Fletcher                 
    
    //update given new length & width
    public update(L: number, a: number) : void
    {
        this.L = L; 
        this.a = a; 
        this.freq = this.c/(2*L) ;
        this.w = this.wFromFreq(this.freq);
        this.propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff();
        this.wallLossCoeff = this.calcWallLossCoeff();
    } 
    
    protected calcWallLossCoeff() : number
    {
        //return 1.0 - (1.2*propogationAttenuationCoeff*L);
        return 1.0 - (2.0*this.propogationAttenuationCoeff*this.L);
    }
    
    protected calcPropogationAttenuationCoeff() : number
    {
        return (2*Math.pow(10, -5)*Math.sqrt(this.w)) / this.a; //changed the constant for more loss, was 2.0
    }
    
    public wFromFreq(frq : number) : number
    {
        return frq*Math.PI*2; 
    }
    
    protected setFreq( f : number ) : void 
    {
        this.wFromFreq(f); 
    }
    
    //the two different bronchi as they connect in1 & in2
    public getWallLossCoeff() : number
    {
        return this.wallLossCoeff;
    } 
}



//this is for testing in the svelte main code for now
export function createSynth()
{
    //initialize the noise and start
    var noise = new SyrinxMembraneFS();

    //make an autofilter to shape the noise
    var autoFilter = new Tone.AutoFilter(Tone.AutoFilter.getDefaults()).connect(Tone.Master);

    //connect the noise
    noise.connect(autoFilter);

    //start the autofilter LFO
    autoFilter.start()  
}

export var strrun : boolean = false; 

function logScale(input : number, min : number, max : number) : number
{
    let b = Math.log( max / min ) / (max - min);
    let a = max / Math.exp(b*max);
    return a * Math.exp ( b*input );     
}

//now just a test of the syrinx
export function pbmStringTest()
{
    const membrane = new SyrinxMembraneFS({pG: 0.0});
    const limiter = new Tone.Limiter(); 
    const compressor = new Tone.Compressor();
    const gain = new Tone.Gain(4); 
    membrane.chain(compressor, limiter, gain, Tone.Destination); 
    
    const pGparam = membrane.pG; 
    const meter = createMicValues();

    const tension = membrane.tension;
    
    let num = meter.getValue();
    if (typeof num === "number")
    {
        setInterval(() => {
        let scaledY = logScale( m.y, 0.001, 1.0 ); 

        let num = meter.getValue();
        //num = logScale( num as number, 0.001, 1.0 );
        let maxPG = ((2000.0*1000*scaledY)-9000000) + 9000000 ;
        maxPG /= 10; 
        //console.log(num);
        pGparam.setValueAtTime((num as number)*maxPG, 0.0); 
        //tension.setValueAtTime(((m.y) * (98902430-19640049.0))+19640049, 0.0);},
        tension.setValueAtTime(((scaledY) * (98913500-64004.0))+64004, 0.0);},
        5);
    }
    else
    {
        console.log ("unhandled meter error - array returned instead of number");
    }
    
}

//---------
//get the mouse values....
let m = { x: 0, y: 0 };
document.body.addEventListener('mousemove', 
function handleMousemove(event) {
    m.x = event.clientX / document.body.clientWidth;
    m.y = event.clientY / document.body.clientHeight;
});
//---------

//from tonejs API example
function createMicValues() : Tone.Meter
{
    //test
    const mic = new Tone.UserMedia();
    const meter = new Tone.Meter();
    meter.normalRange = true;
    mic.open();
    // connect mic to the meter
    mic.connect(meter);
    // the current level of the mic
    //setInterval(() => console.log(meter.getValue()), 50);

    return meter; 
}

export function createTrachealSyrinx()
{
/********* not a flute paper -- chuck code
SyrinxMembrane mem => DelayA delay => lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning
; //from membrane to trachea
//loop => BiQuad hpOut => Gain reduce => dac; //from trachea to sound out
Gain p1; 
wa => p1; 
mem => p1; 
//p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
p1 => delay;   

delay => Gain audioOut; 
delay2 => audioOut; 
audioOut => BiQuad hpOut => dac; 
********/

    //initialize the membrane and start
    var membrane = new SyrinxMembraneFS({pG: 0});

    //the combfilter for the waveguide
    let L : number = 116; //in cm 
    let c : number = 34740; // in m/s
    let LFreq = c/(2*L);
    let period : number = (0.5) / (LFreq) ; //in seconds
    console.log(LFreq);
    var delay = new Delay({ delayTime:period} ); //NOTE: delay is normal buffer delay so has inaccuracies -- very bad. Must fix soon.
    var comb = new CombFilterEffect({ delayTime:period } ); 
    var comb2 = new CombFilterEffect({ delayTime:period } ); 


    //reflection lowpass filter - need to write my own lp
    var lp = new Tone.OnePoleFilter();

    //invert signal
    var flip = new Tone.Negate();

    //the combfilter for the waveguide (2nd)
    var delay2 = new Delay({ delayTime:period} ); 

    ///wall loss attenuation here -- mult. by the coefficient here
    var wallLossCoeff = new WallLossAttenuation();
    var wallloss = new Gain(); 
    wallloss.set({ gain: wallLossCoeff.getWallLossCoeff() })
    delay2.connect(wallloss);
    console.log(wallLossCoeff.getWallLossCoeff());

    //the feedback loop is here
    var p1 : Gain = new Gain();


    let pinkNoise = new Tone.Noise({
        type: "pink"
    });

    //membrane.chain(comb, lp, flip, p1, Tone.Destination);
    //p1.chain(comb);
    //pinkNoise.start(); 
    membrane.chain(comb, lp, flip, p1, Tone.Destination);
    p1.connect(membrane);
    p1.connect(comb);

    const pGparam = membrane.pG; 
    const meter = createMicValues();
    pGparam.setValueAtTime(5.0, 0.0);

    /*
    let num = meter.getValue();
    if (typeof num === "number")
    {
        setInterval(() => {
        let num = meter.getValue();
        pGparam.setValueAtTime((num as number)*10.0, 0.0)}, 50);
        //setInterval(() => console.log(  ), 50);
    }
    else
    {
        console.log ("unhandled meter error - array returned instead of number");
    }
    */

    


    //https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode/parameters
}

//random note here:
//https://www.youtube.com/watch?v=Lz8GgoBZCPg - facetracking
//https://blogs.igalia.com/llepage/webrtc-gstreamer-and-html5-part-1/

