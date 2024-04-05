//Courtney Brown 2023
//Implements a dinosaur syrinx
//This is a work in progress.
//Eventual goal is website + API based on tonejs.
//First goal is exhibition June 2023, sooo.

import * as Tone from 'tone';
import { Gain, optionsFromArguments } from 'tone';
import { Effect, type EffectOptions } from 'tone/build/esm/effect/Effect';
import { ToneAudioWorklet, type ToneAudioWorkletOptions } from "./tonejs_fixed/ToneAudioWorklet";
import { workletName } from "./SyrinxMembraneWorklet.worklet";
import { connectSeries } from "tone/build/esm/core/context/ToneAudioNode";
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';
import { singleIOProcess } from './tonejs_fixed/SingleIOProcessor.worklet';
import { addToWorklet } from './tonejs_fixed/WorkletGlobalScope';
import { Param } from "tone/build/esm/core/context/Param";
import type { NormalRange, Positive } from "tone/build/esm/core/type/Units";

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

function expScale(input: number, min : number, max : number)
{
    //following, y = c*z^10
    // y = c* z^x
    let z = Math.pow(max / min, (1.0/9.0));
    let c = min/z;     
    let res = c*(Math.pow(z, input));;
    return res; 
}

let lastMaxPG = 400; 
export var noiseFloor: number = 0.18;
function scalePGValues(micIn : number, tens: number, ctrlValue : number) : number
{
        //pG is based on the tension

        let maxMaxPG = 400; 
        let floorPG = 400;
        if( tens < 3615563 )
        {
            floorPG = 400; 
            maxMaxPG = 1000; 
        }
        else if(tens < 8017654 )
        {
            floorPG = 1000; 
            maxMaxPG = 1500;
        } 
        else if(tens >= 8017654 )
        {
            floorPG = 1500; 
            maxMaxPG = 5000;            
        }
        let maxPG = ( ctrlValue * (maxMaxPG-floorPG) ) + floorPG; 

        if(  tens > 7017654 && tens < 8217654  )    
            maxPG = (maxPG + lastMaxPG) / 4 ; //smooth out values
        lastMaxPG = maxPG;

        let pG = micIn*maxPG;

        if( ctrlValue < 0.8 )
            pG = Math.min(pG, 2200);  
        else   
            pG = Math.min(pG, 5000);  
 
        //have mouse values modify the tension as well -- try

        //put 0 at the center
        let scaledX = m.x - 0.5; 



        //add or minus a certain amt.
        pG += scaledX*(500*m.y) ;
        pG = Math.max(pG, 0);

    //add in a mic noise floor -- production code now. 1/13/24
    if( micIn < noiseFloor)
    {
        pG = 0;
    }

    //console.log(pG, tens, maxPG);
    return pG;
}

function scaleTension(ctrlValue : number) : number
{
    let tens = 0;
    if( m.y < 0.75 )    
    {
        tens = ((ctrlValue) * (9890243.3116-2083941))+2083941;
    }
    else 
    {
        let addOn = ((0.75) * (9890243.3116-2083941))+2083941;
        tens = ((ctrlValue) * (98989831.3116-addOn))+addOn;
    }

    //add something from the x value

    //put 0 at the center
    let scaledX = m.x - 0.5; 

    //add or minus a certain amt.
    tens += scaledX*(10000000*m.y) ;
    tens = Math.max(0, tens);

    return tens;
}

//now just a test of the syrinx
let alreadyPressed = false; 
export function trachealSyrinx()
{
    document.documentElement.requestFullscreen();


    document.documentElement.requestFullscreen().catch((err) => {
       console.log(
             `Error attempting to enable fullscreen mode: ${err.message} (${err.name})`
         );
     });
    

    if (!alreadyPressed)
    {
        console.log("syrinx code reached"); 

        const membrane = new SyrinxMembraneFS({pG: 0.0});
        const limiter = new Tone.Limiter(); 
        const compressor = new Tone.Compressor();
        const gain = new Tone.Gain(10); 
        membrane.chain(compressor, limiter, gain, Tone.Destination);  

        const meter2 = new Tone.Meter();
        membrane.chain(meter2);

    
        const pGparam = membrane.pG; 
        const meter = createMicValues();

        const tension = membrane.tension;
    
        let num = meter.getValue();
        if (typeof num === "number")
        {
            setInterval(() => {
                let num = meter.getValue();

                let tens=scaleTension(m.y);
                tension.setValueAtTime(tens, 0.0);

                //pG is based on the tension
                let pG = scalePGValues(num as number, tens, m.y)
                pGparam.setValueAtTime(pG, 0.0);  
                
                //const context = Tone.getContext(); 
                //console.log(meter2.getValue());
            },
            5);
        }
        else
        {
            console.log ("unhandled meter error - array returned instead of number");
        }
        alreadyPressed = true;
        console.log("pressed");
    }
}

//---------
//get the mouse values....
let m = { x: 0, y: 0 };
document.body.addEventListener('mousemove', 
function handleMousemove(event) {
    m.x = event.screenX / screen.width;
    m.y = event.screenY / screen.height;
    m.y = 1.0 - m.y; //flip so lower is lower pitched and vice versa

    if (Number.isNaN(m.x) || Number.isNaN(m.y) ) 
    {
        console.log("mouse is NAN!!");
    }
    console.log("x: ",m.x, "y: ",m.y, "cx: ",event.screenX, "cy: ",event.screenY);
    console.log("clientWidth: ",screen.width, "clientHeight: ",screen.height);
});

document.body.addEventListener('touchmove', 
function handleTouchMove(event) {
    let list: TouchList  = event.touches; 
    event.preventDefault(); 

    //ugh, ok, easiest, use first
    let touch = list[0]; 

    m.x = touch.clientX / document.body.clientWidth;
    m.y = touch.clientY / document.body.clientHeight;
    m.y = 1.0 - m.y; //flip so lower is lower pitched and vice versa

    if (Number.isNaN(m.x) || Number.isNaN(m.y) ) 
    {
        console.log("touch is NAN!!");
    }
}, false);

document.body.addEventListener('touchstart', 
function handleTouchStart(event) {
    event.preventDefault(); 
}, false);

document.body.addEventListener('touchend', 
function handleTouchEnd(event) {
    event.preventDefault(); 
}, false);

//---------

//from tonejs API example
function createMicValues() : Tone.Meter
{
    //test
    const mic = new Tone.UserMedia();
    const meter = new Tone.Meter();
    const lp = new Tone.OnePoleFilter();
    meter.normalRange = true;
    mic.open();
    // connect mic to the meter
    mic.chain(lp, meter);
    // the current level of the mic
    //setInterval(() => console.log(meter.getValue()), 50);

    return meter; 
}



    //https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode/parameters


//random note here:
//https://www.youtube.com/watch?v=Lz8GgoBZCPg - facetracking
//https://blogs.igalia.com/llepage/webrtc-gstreamer-and-html5-part-1/

