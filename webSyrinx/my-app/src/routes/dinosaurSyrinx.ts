//Courtney Brown 2023
//Implements a dinosaur syrinx
//This is a work in progress.
//Eventual goal is website + API based on tonejs.
//First goal is exhibition June 2023, sooo.
//NOTE: To get RPI work as a webcam, use this help thread: https://forums.raspberrypi.com/viewtopic.php?t=359204
//for easy access, the command to stream is - TODO: put this in a script --:
//gst-launch-1.0 libcamerasrc ! "video/x-raw,width=1280,height=1080,format=YUY2",interlace-mode=progressive ! videoconvert ! v4l2sink device=/dev/video8

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
import {mouthDataFile} from "./faceDetection/mouthMeasures";

//TODO: create third "header file" for stored mouth values 5/29/2024

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
    membraneCount: Positive;
    rightTension: Positive;
    independentMembranes: Positive;
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
 * tension 
 * @min 0
 * @max 
 */
    readonly rightTension: Param<"positive">;

    readonly independentMembranes: Param<"positive">


    /**
     * membraneCount 
     * @min 1
     * @max 2
     */
    readonly membraneCount: Param<"positive">;

    /**
     * The node which creates the syrinx membrane. Runs in an AudioWorklet when possible.
     */
    private _membraneWorklet: FletcherSmythSyrinxMembraneWorklet;

    constructor(pG?: Positive, tension?: Positive);
    constructor(options?: Partial<MembraneWorkletOptions>);
    constructor() {
        super(optionsFromArguments(SyrinxMembraneFS.getDefaults(), arguments, ["pG", "tension", "membraneCount", "rightTension", "independentMembranes"]));
        const options = optionsFromArguments(SyrinxMembraneFS.getDefaults(), arguments, ["pG", "tension", "membraneCount", "rightTension", "independentMembranes"]);

        this._membraneWorklet = new FletcherSmythSyrinxMembraneWorklet({
            context: this.context,
            pG: options.pG,
            tension: options.tension,
            membraneCount: options.membraneCount,
            rightTension: options.rightTension,
            independentMembranes: options.independentMembranes
        });
        // connect it up
        this.connectEffect(this._membraneWorklet);

        this.pG = this._membraneWorklet.pG;
        this.tension = this._membraneWorklet.tension;
        this.membraneCount = this._membraneWorklet.membraneCount;
        this.rightTension = this._membraneWorklet.rightTension;
        this.independentMembranes = this._membraneWorklet.independentMembranes;
    }

    static getDefaults(): MembraneOptions {
        return Object.assign(Effect.getDefaults(), {
            pG: 0.0,
            tension: 2000,
            membraneCount: 2,
            rightTension: 2000,
            independentMembranes: 0
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
    membraneCount: number;
    rightTension: number;
    independentMembranes: number;
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
    readonly tension: Param<"positive">; //this is also the left tension if membraneCount is 2

    //implemented
    readonly rightTension: Param<"positive">;
    readonly independentMembranes: Param<"positive">;

    //change syrinx membrane number - 1 or 2
    readonly membraneCount: Param<"positive">;

    constructor(pG?: Positive, tension?: Positive, membraneCount?: Positive, rightTension?: Positive, independentMembranes?: Positive);
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
            value: options.tension,
            units: "positive",
            minValue: 0,
            maxValue: 168397230,
            param: this._dummyParam,
            swappable: true,
        });

        this.rightTension = new Param<"positive">({
            context: this.context,
            value: options.rightTension,
            units: "positive",
            minValue: 0,
            maxValue: 168397230,
            param: this._dummyParam,
            swappable: true,
        });

        this.independentMembranes = new Param<"positive">({
            context: this.context,
            value: options.independentMembranes,
            units: "positive",
            minValue: 0,
            maxValue: 1,
            param: this._dummyParam,
            swappable: true,
        });



        this.membraneCount = new Param<"positive">({
            context: this.context,
            value: options.membraneCount,
            units: "positive",
            minValue: 1,
            maxValue: 2,
            param: this._dummyParam,
            swappable: true,
        });

    }

    static getDefaults(): MembraneWorkletOptions {
        return Object.assign(ToneAudioWorklet.getDefaults(), {
            pG: 5.0,
            tension: 2000,
            membraneCount: 2,
            rightTension: 2000,
            independentMembranes: 0
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
        const memCount = node.parameters.get("membraneCount") as AudioParam;
        this.membraneCount.setParam(memCount);
        const righttension = node.parameters.get("rightTension") as AudioParam;
        this.rightTension.setParam(righttension);
        const independentMembranes = node.parameters.get("independentMembranes") as AudioParam;
        this.independentMembranes.setParam(independentMembranes);
    }

    dispose(): this {
        super.dispose();
        this.input.dispose();
        this.output.dispose();
        this.pG.dispose();
        this.tension.dispose();
        this.membraneCount.dispose();
        this.rightTension.dispose();
        this.independentMembranes.dispose();
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
    protected freq = this.c / (2 * this.L);
    protected w = this.wFromFreq(this.freq);
    //150.0*2.0*pi => float w;  

    protected a = 0.35; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
    //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    protected propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff(); //theta in Fletcher1988 p466
    protected wallLossCoeff = this.calcWallLossCoeff(); //beta in Fletcher                 

    //update given new length & width
    public update(L: number, a: number): void {
        this.L = L;
        this.a = a;
        this.freq = this.c / (2 * L);
        this.w = this.wFromFreq(this.freq);
        this.propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff();
        this.wallLossCoeff = this.calcWallLossCoeff();
    }

    protected calcWallLossCoeff(): number {
        //return 1.0 - (1.2*propogationAttenuationCoeff*L);
        return 1.0 - (2.0 * this.propogationAttenuationCoeff * this.L);
    }

    protected calcPropogationAttenuationCoeff(): number {
        return (2 * Math.pow(10, -5) * Math.sqrt(this.w)) / this.a; //changed the constant for more loss, was 2.0
    }

    public wFromFreq(frq: number): number {
        return frq * Math.PI * 2;
    }

    protected setFreq(f: number): void {
        this.wFromFreq(f);
    }

    //the two different bronchi as they connect in1 & in2
    public getWallLossCoeff(): number {
        return this.wallLossCoeff;
    }
}



//this is for testing in the svelte main code for now
export function createSynth() {
    //initialize the noise and start
    var noise = new SyrinxMembraneFS();

    //make an autofilter to shape the noise
    var autoFilter = new Tone.AutoFilter(Tone.AutoFilter.getDefaults()).connect(Tone.Master);

    //connect the noise
    noise.connect(autoFilter);

    //start the autofilter LFO
    autoFilter.start()
}

export var strrun: boolean = false;

function logScale(input: number, min: number, max: number): number {
    let b = Math.log(max / min) / (max - min);
    let a = max / Math.exp(b * max);
    return a * Math.exp(b * input);
}

function expScale(input: number, min: number, max: number) {
    //following, y = c*z^10
    // y = c* z^x
    let z = Math.pow(max / min, (1.0 / 9.0));
    let c = min / z;
    let res = c * (Math.pow(z, input));;
    return res;
}





let lastMaxPG = 400;
function scalePGValuesTwoMembranes(micIn: number, tens: number, ctrlValue: number): number {
    //pG is based on the tension

    let maxMaxPG = 400;
    let floorPG = 400;
    if (tens < 3615563) {
        floorPG = 400;
        maxMaxPG = 1000;
    }
    else if (tens < 8017654) {
        floorPG = 1000;
        maxMaxPG = 1500;
    }
    else if (tens >= 8017654) {
        floorPG = 1500;
        maxMaxPG = 5000;
    }
    let maxPG = (ctrlValue * (maxMaxPG - floorPG)) + floorPG;

    if (tens > 7017654 && tens < 8217654)
        maxPG = (maxPG + lastMaxPG) / 4; //smooth out values
    lastMaxPG = maxPG;

    let pG = micIn * maxPG;

    if (ctrlValue < 0.8)
        pG = Math.min(pG, 2200);
    else
        pG = Math.min(pG, 5000);

    //have mouse values modify the tension as well -- try

    //put 0 at the center
    let scaledX = m.x - 0.5;

    //add or minus a certain amt.
    pG += scaledX * (100 * m.y); //note: was 500
    pG = Math.max(pG, 0);

    //console.log(pG, tens, maxPG);
    return pG;
}

function scalePGValuesOneMembrane(micIn: number, tens: number, ctrlValue: number): number {
    var maxPG = 2000;

    //adjust for environmental noise
    micIn = micIn - 0.15;
    micIn = Math.max(0, micIn);

    var pG = micIn * maxPG;
    var p = 1;
    if (micIn != 0) {
        p = logScale(micIn, 1.0, 10.0);
    }
    pG = p * pG * 7000.0;
    pG = Math.min(pG, 200000);

    //console.log(micIn, tens, pG, ctrlValue);

    return pG;
}

function scaleTensionTwoMembranes(ctrlValue: number): number {
    let tens = 0;
    if (m.y < 0.75) {
        tens = ((ctrlValue) * (9890243.3116 - 2083941)) + 2083941;
    }
    else {
        let addOn = ((0.75) * (9890243.3116 - 2083941)) + 2083941;
        tens = ((ctrlValue) * (98989831.3116 - addOn)) + addOn;
    }

    //add something from the x value

    //put 0 at the center
    let scaledX = m.x - 0.5;

    //add or minus a certain amt.
    tens += scaledX * (10000000 * m.y);
    tens = Math.max(0, tens);

    return tens;
}

///--------------------------------------------------------------------------------------------
///----------Quick averaging low pass filter for tension -- needs to be refactored I do have classes for this from another project....
//-- originally wrote this to see if that's why things were going haywire and yes, it was
/// if tension changes too fast its terrrible. TODO: refactor & use data structure
///--------------------------------------------------------------------------------------------
//todo: refactor this out and freaking clean this up
export var minTens = 941;
let tensBuffer : number[] = [];
let maxTensBuffer : number = 5; //we'll see what it needs to be
let lastTens =0;
let maxStep = 200;
function avgFilterTension(input: number) : number
{
    // if( input < 50 && input <  lastTens  )
    // {
    //     maxStep = 5;
    // }
    // else 
    // {
    //     //8510292
    //     maxStep = 1000000;
    // }

    tensBuffer.push(input);
    if( tensBuffer.length >= maxTensBuffer) //its a queue
    {
        tensBuffer.splice(0, 1);
    }

    let sum=0;
    for(let i=0; i<tensBuffer.length; i++)
    {
        sum += tensBuffer[i];
    }
    let res = sum / tensBuffer.length;
    // let step = lastTens - res;

    // if (step > Math.abs(maxStep))
    // {
    //     if( step > 0)
    //         res = lastTens + maxStep;
    //     else
    //         res = lastTens - maxStep;

    //     tensBuffer.push(res);
    //     if( tensBuffer.length >= maxTensBuffer) //its a queue
    //     {
    //         tensBuffer.splice(0, 1);
    //     }
    // }
    // lastTens = res;
    return res;
}


///--------------------------------------------------------------------------------------------
///--------------------------------------------------------------------------------------------
let pgBuffer : number[] = [];
let maxPGBuffer : number = 10  ; //we'll see what it needs to be
let lastPG = 0;
let maxPGStep = 100000;
function avgFilterPG(input: number) : number
{
    // if( input < 10 && input <  lastPG )
    // {
    //     maxPGStep = 1;
    // }
    // else 
    // {
    //     maxPGStep = 100000;
    // }

    pgBuffer.push(input);
    if( pgBuffer.length >= maxPGBuffer) //its a queue
    {
        pgBuffer.splice(0, 1);
    }

    let sum=0;
    for(let i=0; i<pgBuffer.length; i++)
    {
        sum += pgBuffer[i];
    }

    let res = sum / pgBuffer.length;
    // let step = lastPG - res;
    // if (step > Math.abs(maxPGStep))
    // {
    //     if( step > 0)
    //         res = lastPG + maxPGStep;
    //     else
    //         res = lastPG - maxPGStep;

    //     pgBuffer.push(res);
    //     if( pgBuffer.length >= maxPGBuffer) //its a queue
    //     {
    //         pgBuffer.splice(0, 1);
    //     }
    // }
    // lastPG = res;
    return res;


}
///--------------------------------------------------------------------------------------------
///--------------------------------------------------------------------------------------------
///--------------------------------------------------------------------------------------------
//we see -- testing for mouth-scaling
function scaleTensionOnlyLow(ctrlValue: number, xctrl: number): number {
    let tens = 0;
    let maxTens = 808510292;
    let maxTens2 = 16615563;
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

    return tens;
}


//pG for only low
export var noiseFloor: number = 0.05; //trying a lower noise floor, was 0.18
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
        maxMaxPG = 40;
        // maxMaxPG = 20;
    }
    else if (tens < 656080) {
        maxMaxPG = 45;
        // maxMaxPG = 25;
    }
    else if (tens < 1656080) {
        maxMaxPG = 90;
        // maxMaxPG = 50;
    }
    else if (tens < 3015563) {
        maxMaxPG = 120;

        // maxMaxPG = 75;
    }
    else if (tens < 4515563) {
        // maxMaxPG = 90;
        maxMaxPG = 150;

    }
    else if (tens < 6015563) {   //5675073.28 8027448.10
        floorPG = 20; //changed from 400
        maxMaxPG = 120;
    }
    else if (tens<7015563) { 

        floorPG = 90;
        maxMaxPG = 90;
    }
    else 
    {
        floorPG = 20;
        maxMaxPG = 200;
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


function scaleTensionOneMembrane(ctrlValue: number): number {
    let minTens = 200;
    let maxTens = 22000000;
    let tens = ctrlValue * (maxTens - minTens) + minTens;

    //put 0 at the center
    let scaledX = m.x - 0.5;

    //add or minus a certain amt.
    tens += scaledX * (10000000 * m.y);
    tens = Math.max(0, tens);

    return tens;
}

//this needed as the audio interface/mic amplititude response reduces substantially when using the webcam at the same time.
export var micScaling: Record<'soft' | 'loud', number> = { soft :0.0,  loud: 1.0} ;
function scaleMicValues(micIn : number) : number
{
    //adjust threshols
    //return  micIn * (micScaling.loud-micScaling.soft) + micScaling.soft;
    let res = (micIn - micScaling.soft)/(micScaling.loud - micScaling.soft);
    res = Math.min(1.0, res); //cap it at 1.0
    return res; 
}

//--------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------
//Main syrinx function main
let alreadyPressed = false;
var membrane: SyrinxMembraneFS;
var currentMembraneCount = 2; //default
var independentMembranes = false; //default
export var useMouse = true; //default
export var curMicIn = 0.0;
export var curMaxMicIn = { max: 0.0};
export var tens = 0.0;
var recordingData = false; //whether we are recording data to file from the UI

export function trachealSyrinx() {
    //document.documentElement.requestFullscreen();

    let micConfigStatus : HTMLLabelElement = document.getElementById("micConfigStatus") as HTMLLabelElement; // status for mic config

    // document.documentElement.requestFullscreen().catch((err) => {
    //   console.log(
    //         `Error attempting to enable fullscreen mode: ${err.message} (${err.name})`
    //     );
    // });

    if (!alreadyPressed) {

        const limiter = new Tone.Limiter();
        const compressor = new Tone.Compressor();
        const gain = new Tone.Gain(50); //to do -- make visible to UI
        membrane = new SyrinxMembraneFS({ pG: 0.0 }); //needs to be global.. 


        membrane.chain(compressor, limiter, gain, Tone.Destination);

        const meter2 = new Tone.Meter();
        membrane.chain(meter2);

        const pGparam = membrane.pG;
        const meter = createMicValues();

        const tension = membrane.tension;
        const rightTension = membrane.rightTension;

        let num = meter.getValue();
        if (typeof num === "number") {
            setInterval(() => {
                let num = meter.getValue();
                curMicIn = num as number;
                curMaxMicIn.max = Math.max(curMaxMicIn.max, curMicIn);

                num = scaleMicValues(num as number);
                micConfigStatus.innerHTML = "Mic raw: " + curMicIn.toFixed(2) + " Scaled: " + num.toFixed(2)  + " Recorded Max: " + curMaxMicIn.max.toFixed(2) + " Scaled Max: " + micScaling.loud.toFixed(2);
                //console.log("Mic raw: " + curMicIn.toFixed(2) + " Scaled: " + num.toFixed(2)  + " Recorded Max: " + curMaxMicIn.max.toFixed(2) + " Scaled Max: " + micScaling.loud.toFixed(2));

                //let tens = scaleTensionTwoMembranes(m.y);
                tens = avgFilterTension(scaleTensionOnlyLmuow(m.y, m.x));

                console.log(m.y, m.x, tens);

                
                 //console.log(tens);
                 //let tens = avgFilterTension(scaleTensionTwoMembranes(m.y));

                let rightTens = 0;
                if (currentMembraneCount == 1) {
                    tens = scaleTensionOneMembrane(m.y);
                }

                //tens = 3315563; //testing value   
                rightTension.setValueAtTime(tens, 0.0); 
                tension.setValueAtTime(tens, 0.0);

                //pG is based on the tension
                 //let pG = scalePGValuesTwoMembranes(num as number, tens, m.y); //TODO: find PG given 2 separate membrane values
                let pG = avgFilterPG(scalePGValuesLow(num as number, tens, m.y)); //TODO: find PG given 2 separate membrane values


                //console.log("pG: " + pG.toFixed(2) + " tens: " + tens.toFixed(2));

                // if( recordingData )
                // {
                //     mouthSavedData += wideMin +"," +wideMax +"," + mouthAreaMin+","+mouthAreaMax+"\n"; //save mouth data
                // }

               // pG = 1200; //testing value
                if (currentMembraneCount == 1) {
                    pG = pG * 8;
                    //pG = scalePGValuesOneMembrane(num as number, tens, m.y);   
                }

                pGparam.setValueAtTime(pG, 0.0);
        },
        5);
    }
    else {
        console.log("unhandled meter error - array returned instead of number");
    }
    alreadyPressed = true;
    console.log("pressed");
}
}

//retired until I figure shit out.
export function membranesIndependent(event: any) {
    if (!alreadyPressed) {
        trachealSyrinx();
    }

    independentMembranes = !independentMembranes;

    if (independentMembranes) {
        membrane.independentMembranes.setValueAtTime(1, 0.0);
        event.currentTarget.innerHTML = "Press for Membranes with Shared Tension";
    }
    else {
        membrane.independentMembranes.setValueAtTime(0, 0.0);
        event.currentTarget.innerHTML = "Press for Independent Membranes";
    }
}

export function setMembraneCount(mcount: number) {
    //initialize syrinx if not initialized.....
    if (!alreadyPressed) {
        trachealSyrinx();
    }
    const membraneNumber = membrane.membraneCount;
    membraneNumber.setValueAtTime(mcount, 0.0); //try with one membrane
    currentMembraneCount = mcount;
    //console.log("currentMembraneCount: " + currentMembraneCount );
}

//---------
//get the mouse values....
export var m = { x: 0, y: 0 };
document.body.addEventListener('mousemove',
    function handleMousemove(event) {
        if( useMouse )
        {
            m.x = event.screenX / screen.height;
            m.y = event.screenY / screen.width;
            m.y = 1.0 - m.y; //flip so lower is lower pitched and vice versa

            if (Number.isNaN(m.x) || Number.isNaN(m.y)) {
                console.log("mouse is NAN!!");
             }
        }
    });

document.body.addEventListener('touchmove',
    function handleTouchMove(event) {
        let list: TouchList = event.touches;
        event.preventDefault();

        //ugh, ok, easiest, use first
        let touch = list[0];

        if( useMouse )
        {
            m.x = touch.clientX / document.body.clientWidth;
            m.y = touch.clientY / document.body.clientHeight;
            m.y = 1.0 - m.y; //flip so lower is lower pitched and vice versa

             if (Number.isNaN(m.x) || Number.isNaN(m.y)) {
                console.log("touch is NAN!!");
            }
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

//     //keyboard commands for saving data
document.body.addEventListener('keydown',
function keyDownloadFile(event) {
    if (event.key === "f") {
        mouthDataFile.downloadFile();
    }
    // else if (event.key === "c") {
    //     console.log("cleared");
    //     mouthSavedData = "wideMin, wideMax, mouthAreaMin, mouthAreaMax\n"; //start with the headers
    // }
    // else if(event.key === "r") //this is for recording data & it will reset the file as well..
    // {
    //     recordingData = !recordingData;
    //     mouthSavedData = "wideMin, wideMax, mouthAreaMin, mouthAreaMax\n"; //start with the headers
    //     console.log("recording: " + recordingData);
    // }

}, false);   

//---------

//from tonejs API example
function createMicValues(): Tone.Meter {
    //test
    const mic = new Tone.UserMedia();
    const meter = new Tone.Meter();
    const lp = new Tone.OnePoleFilter();

    const notch = new Tone.Filter(250, "notch"); //get rid of dino feedback
    const notch2 = new Tone.Filter(500, "notch"); //get rid of dino feedback
    const notchLowFeedback = new Tone.Filter(92, "notch"); //get rid of dino feedback

    const notchfan = new Tone.Filter(86*2, "notch"); //get rid of the fan noise -- https://noctua.at/pub/media/wysiwyg/Noctua_PWM_specifications_white_paper.pdf
//const notch3 = new Tone.Filter(750, "notch"); //get rid of dino feedback
    //const notch4 = new Tone.Filter(250/2, "notch"); //get rid of dino feedback


    meter.normalRange = true;
    mic.open();
    // connect mic to the meter
    mic.chain(notch, notch2, notchfan, notchLowFeedback, lp, meter);
    // the current level of the mic
    //setInterval(() => console.log(meter.getValue()), 50);

    return meter;
}



//https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode/parameters


//random note here:
//https://www.youtube.com/watch?v=Lz8GgoBZCPg - facetracking
//https://blogs.igalia.com/llepage/webrtc-gstreamer-and-html5-part-1/

