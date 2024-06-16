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
    Ps: Positive; 

    //for now, not used, using inputMusclePressure instead which includes both values
    ptl: Positive;
    pt : number;

    inputMusclePressure: NormalRange;
    syrinxModel: Positive;
}
export class SyrinxMembraneModel extends Effect<MembraneOptions> {

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
	 * Ps - input air pressure to Elemans / Zaccharelli model 
	 * @min 0
	 * @max 
	 */
    readonly Ps: Param<"positive">;


    //****** don't use these for now, replacing with inputMusclePressure, a single value for all syrinx muscle pressure */
     /**
	 * ptl - pressure from ptl, changes pitch/timbre in Elemans / Zaccharelli model
	 * @min 0
	 * @max 
	 */
    readonly ptl: Param<"positive">;

     /**
	 * pt - transmural syrinx pressure in Elemans / Zaccharelli model -- by default, users can't modify this
     * but I might change that.
	 * @min 0
	 * @max 
	 */
     readonly pt: Param<"number">;

/****** end Do not use portion lol */


     /**
	 * all muscle pressure in Elemans / Zaccharelli model -- by default, users can't modify this
     * but I might change that.
	 * @min 0
	 * @max 
	 */
     readonly inputMusclePressure: Param<"normalRange">;

     /**
	 * which syrinx model to use -- right now, Fletcher/Smyth- 0 or Elemans/Zaccharelli - 1
     * but I might change that.
	 * @min 0
	 * @max 
	 */
     readonly syrinxModel: Param<"positive">;


	/**
	 * The node which does the syrinx membrane. Runs in an AudioWorklet when possible.
	 */
	private _membraneWorklet: SyrinxMembraneWorklet;

	constructor(pG?: Positive, tension?: Positive);
	constructor(options?: Partial<MembraneWorkletOptions>);
	constructor() {
		super(optionsFromArguments(SyrinxMembraneModel.getDefaults(), arguments, ["pG", "tension", "Ps", "ptl", "pt", "inputMusclePressure", "syrinxModel"]));
		const options = optionsFromArguments(SyrinxMembraneModel.getDefaults(), arguments, ["pG", "tension", "Ps", "ptl", "pt", "inputMusclePressure", "syrinxModel"]);

		this._membraneWorklet = new SyrinxMembraneWorklet({
			context: this.context,
			pG: options.pG,
            tension: options.tension,
            Ps : options.Ps,
            ptl : options.ptl,
            pt : options.pt, 
            inputMusclePressure: options.inputMusclePressure,
            syrinxModel: options.syrinxModel
		});
		// connect it up
		this.connectEffect(this._membraneWorklet);

		this.pG = this._membraneWorklet.pG;
        this.tension = this._membraneWorklet.tension; 
        this.Ps = this._membraneWorklet.Ps; 
        this.ptl = this._membraneWorklet.ptl;
        this.pt = this._membraneWorklet.pt;
        this.inputMusclePressure = this._membraneWorklet.inputMusclePressure;
        this.syrinxModel = this._membraneWorklet.syrinxModel;

	}

	static getDefaults(): MembraneOptions {
		return Object.assign(Effect.getDefaults(), {
			pG: 0.0, 
            tension: 2000, 
            Ps: 0.0,
            ptl: 0.0,
            pt : 0.0, 
            inputMusclePressure: 0.0,
            syrinxModel: 0.0
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
    Ps: number;
    ptl: number;
    pt: number;
    syrinxModel: number;
    inputMusclePressure: number;
}

//create the Syrinx Membrane Effect -- it has to be an effect with a source, as the membrane requires an input 
//as well
export class SyrinxMembraneWorklet extends ToneAudioWorklet<MembraneWorkletOptions> 
{
    readonly name: string = "FletcherSmythSyrinxMembrane";
    
    readonly input: Gain;
	readonly output: Gain;

    /**
	 * The amount of delay of the comb filter.
	 */
	readonly pG: Param<"positive">;
    readonly tension: Param<"positive">;
    readonly Ps: Param<"positive">;
    readonly ptl: Param<"positive">;
    readonly pt: Param<"number">;
    readonly inputMusclePressure: Param<"normalRange">;
    readonly syrinxModel: Param<"positive">;


	constructor(pG?: Positive, tension?: Positive);
	constructor(options?: RecursivePartial<MembraneWorkletOptions>);
	constructor() {
        addToWorklet(singleIOProcess);
		super(optionsFromArguments(SyrinxMembraneWorklet.getDefaults(), arguments));
		const options = optionsFromArguments(SyrinxMembraneWorklet.getDefaults(), arguments);

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

        this.Ps = new Param<"positive">({
            context: this.context,
            value: options.Ps,
            units: "positive",
            minValue: 0,
            maxValue: 1,
            param: this._dummyParam,
            swappable: true,
        });

        this.ptl = new Param<"positive">({
            context: this.context,
            value: options.ptl,
            units: "positive",
            minValue: 0,
            maxValue: 40,
            param: this._dummyParam,
            swappable: true,
        });

        this.pt = new Param<"number">({
            context: this.context,
            value: options.ptl,
            units: "number",
            minValue: -2,
            maxValue: 2,
            param: this._dummyParam,
            swappable: true,
        });


        this.inputMusclePressure = new Param<"normalRange">({
            context: this.context,
            value: options.ptl,
            units: "normalRange",
            minValue: 0,
            maxValue: 1,
            param: this._dummyParam,
            swappable: true,
        });


        this.syrinxModel = new Param<"positive">({
            context: this.context,
            value: options.ptl,
            units: "positive",
            minValue: 0,
            maxValue: 1,
            param: this._dummyParam,
            swappable: true,
        });
	}

    static getDefaults(): MembraneWorkletOptions {
		return Object.assign(ToneAudioWorklet.getDefaults(), {
			pG: 5.0,
            tension: 2000,
            Ps:0.0,
            ptl:0.0,
            pt:0.0, 
            inputMusclePressure: 0.0,
            syrinxModel: 1
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

        //Elemans / Zaccharelli model
        const Ps = node.parameters.get("Ps") as AudioParam;
		this.Ps.setParam(Ps);
        const ptl = node.parameters.get("ptl") as AudioParam;
        this.ptl.setParam(ptl);
        const pt = node.parameters.get("pt") as AudioParam;
        this.pt.setParam(pt);
        const inputMusclePressure = node.parameters.get("inputMusclePressure") as AudioParam;
        this.inputMusclePressure.setParam(inputMusclePressure);
        const syrinxModel = node.parameters.get("syrinxModel") as AudioParam;
        this.syrinxModel.setParam(syrinxModel);
	}

    dispose(): this {
		super.dispose();
		this.input.dispose();
		this.output.dispose();
        this.pG.dispose(); 
        this.tension.dispose(); 

        this.Ps.dispose();
        this.ptl.dispose();
        this.pt.dispose();
        this.inputMusclePressure.dispose();
        this.syrinxModel.dispose();

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
    var noise = new SyrinxMembraneModel();

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
export var noiseFloor: number = 0.25;
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

function scaleTensionLow(ctrlValue: number, xctrl: number): number {
    let tens = 0;
    let maxTens = 808510292;
    let maxTens2 = 10615563;
    // if (m.y < 0.75) {
    //     tens = ((ctrlValue) * (9890243.3116 - 2083941)) + 2083941;
    // }
    // else {
    //     let addOn = ((0.75) * (9890243.3116 - 2083941)) + 2083941;
    //     tens = ((ctrlValue) * (98989831.3116 - addOn)) + addOn;
    // }

    tens = ((ctrlValue) * (maxTens2- 156080)) + 156080;

    //add something from the x value

    //put 0 at the center
    let scaledX = m.x ; //take out this for mouth -- have it only add.

    //add or minus a certain amt.
    tens += scaledX * (10000 * m.y); //have what the area adds be a percentage of the wideness.
    tens = Math.max(156080, tens);
    //tens = Math.min(maxTens, tens);
    //console.log( tens );

    return tens;
}

function scalePGValuesLow(micIn: number, tens: number, ctrlValue: number): number {
    //pG is based on the tension

    let maxMaxPG = 400; //656080.2213529117

    let floorPG = 20;
    if (tens < 256080) {  
        maxMaxPG = 8;
    }
    else if (tens < 356080) {
        maxMaxPG = 9;
    }
    else if (tens < 400800) {
        maxMaxPG = 10;
    }
    else if (tens < 456080) {
        maxMaxPG = 20;
    }
    else if (tens < 656080) {
        maxMaxPG = 25;
    }
    else if (tens < 1656080) { //12547837.826411683
        maxMaxPG = 50;
    }
    else if (tens < 3015563) {
        maxMaxPG = 75;
    }
    else if (tens < 4515563) {
        maxMaxPG = 90;
    }
    else if (tens < 6015563) {   //5675073.28 8027448.10
        floorPG = 20; //changed from 400
        maxMaxPG = 100;
    }
    else if (tens<7015563) { 

        floorPG = 90;
        maxMaxPG = 150;
    }
    else if (tens < 8015563) {
    
        floorPG = 20;
        maxMaxPG = 200;
    }
    else if (tens < 10015563) {

        floorPG = 20;
        maxMaxPG = 250;
    }
    else
    {
        floorPG = 20;
        maxMaxPG = 300;
    }

    let maxPG = maxMaxPG;// (ctrlValue * (maxMaxPG - floorPG)) + floorPG;
    let oldMaxPG = (ctrlValue * (maxMaxPG - floorPG)) + floorPG;

    let rawMicIn = micIn;
    //micIn = logScale(micIn, 0.0000001, 1.0) * 3.0;
    let pG = micIn * maxPG ;
    pG *= 3; 

    //put 0 at the center
    let scaledX = ctrlValue; //don't subtract right now.

    //add or minus a certain amt.
    
    if (pG > 30) //don't add if pG is already super low
        {pG += scaledX * (100 * m.y);} //note: was 500} //just adds a little
        

    //add in a mic noise floor -- production code now. 1/13/24
    if( micIn < noiseFloor)
    {
        pG = 0;
    }

    pG = Math.max(pG, 0);
    // if(rawMicIn < 0.04)
    // {
    //     pG=0;
    // }

    //console.log(micIn.toFixed(2), pG.toFixed(2), tens.toFixed(2));
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

//both paramters need to be normalized to 0-1
function scaleElemansPsMaxWithScaledValues(tension : number, ps : number) : number
{
    //from polynomial fitting of the data
    //[[-0.05909785  1.11988446 -2.61913351  1.79788292]]
    //[0.02962862]

    let psMax = -0.05909785*tension*tension*tension*tension + 1.11988446*tension*tension*tension - 2.61913351*tension*tension + 1.79788292*tension + 0.02962862;

    return psMax * ps;
}

//now just a test of the syrinx
let alreadyPressed = false; 
let recordingMouseData = false;
export function trachealSyrinx()
{
    //don't do full screen for website version
    // document.documentElement.requestFullscreen().catch((err) => {
    //    console.log(
    //          `Error attempting to enable fullscreen mode: ${err.message} (${err.name})`
    //      );
    //  });
    

    if (!alreadyPressed)
    {
        console.log("syrinx code reached"); 

        const limiter = new Tone.Limiter(); 
        const compressor = new Tone.Compressor();
        const gain = new Tone.Gain(10); 
        const lp = new Tone.Filter(200, "lowpass"); //smooth out some edges in the sound, perhaps as tissue would I don't know.
        lp.Q.value = 10; //make it a bit more resonant

        const meter2 = new Tone.Meter();

        var vol = new Tone.Volume(10);
        const membrane = new SyrinxMembraneModel({pG: 0.0});

        membrane.chain(lp, compressor, limiter, gain, vol, Tone.Destination);  
        membrane.chain(meter2);

        console.log(membrane);

        const pGparam = membrane.pG; 
        const meter = createMicValues();

        const tension = membrane.tension;

        const inputMusclePressure = membrane.inputMusclePressure;
        const Ps = membrane.Ps;
    
        let num = meter.getValue();
        let audioMax = 0.0;
        if (typeof num === "number")
        {
            setInterval(() => {
                let num = meter.getValue();

                // let tens=scaleTensionLow(m.y, m.x);
                // tension.setValueAtTime(tens, 0.0);

                // //pG is based on the tension
                // let pG = scalePGValuesLow(num as number, tens, m.y);
                // pGparam.setValueAtTime(pG, 0.0);  
                //let p = (num as number) * 0.05; //for blowing, for now
                //let p = m.x;
                let p = scaleElemansPsMaxWithScaledValues(m.y, m.x); //for mouse control
                //let p = scaleElemansPsMaxWithScaledValues(m.y, num as number); //for breath control
                Ps.setValueAtTime(p, 0.0);

                //save the data
                if( recordingMouseData )
                    psMouseData += p + "," + m.y + "\n";

                //console.log(num as number);
                inputMusclePressure.setValueAtTime(m.y, 0.0);
                
                //const context = Tone.getContext(); 
            },
            5);
        }
        else
        {
            console.log ("unhandled meter error - array returned instead of number");
        }
        alreadyPressed = true;
        console.log("pressed");

        console.log("sample rate: " + Tone.context.sampleRate);
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

//for saving data
document.body.addEventListener('keydown',
function keyDownloadFile(event) {
    if (event.key === "f") {
        downloadFile();
    }
    else if (event.key === "c") {
        console.log("cleared");
        psMouseData = "";
    }
    else if(event.key === "r")
    {
        recordingMouseData = !recordingMouseData;
        console.log("recording: " + recordingMouseData);
    }

}, false);   

//---------

//from tonejs API example
function createMicValues() : Tone.Meter
{
    //test
    const mic = new Tone.UserMedia();
    const meter = new Tone.Meter();
    const lp = new Tone.OnePoleFilter();
    const lp2 = new Tone.OnePoleFilter();

    const notch = new Tone.Filter(250, "notch"); //get rid of dino feedback
    meter.normalRange = true;
    mic.open();
    // connect mic to the meter
    mic.chain(notch, lp, lp2, meter);
    // the current level of the mic
    //setInterval(() => console.log(meter.getValue()), 50);

    return meter; 
}

//modified from https://www.tutorialspoint.com/how-to-create-and-save-text-file-in-javascript
var psMouseData ="";
export const downloadFile = () => {
    const link = document.createElement("a");
    const file = new Blob([psMouseData], { type: 'text/plain' });
    link.href = URL.createObjectURL(file);
    link.download = "psMouseData.csv";
    link.click();
    URL.revokeObjectURL(link.href);
}

    //https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode/parameters


//random note here:
//https://www.youtube.com/watch?v=Lz8GgoBZCPg - facetracking
//https://blogs.igalia.com/llepage/webrtc-gstreamer-and-html5-part-1/

