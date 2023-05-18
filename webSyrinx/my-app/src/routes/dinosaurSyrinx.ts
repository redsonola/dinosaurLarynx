import * as Tone from 'tone';
import { Gain, optionsFromArguments } from 'tone';
import { Time } from 'tone';
import { Source, type SourceOptions } from 'tone/build/esm/source/Source';
import { Effect, type EffectOptions } from 'tone/build/esm/effect/Effect';
import { ToneAudioWorklet } from "./tonejs_fixed/ToneAudioWorklet";
import { FeedbackCombFilter } from "./tonejs_fixed/FeedbackCombFilter";
import { workletName } from "./SyrinxMembraneWorklet.worklet";
import { connectSeries, ToneAudioNode, type ToneAudioNodeOptions } from "tone/build/esm/core/context/ToneAudioNode";
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';
import { singleIOProcess } from './tonejs_fixed/SingleIOProcessor.worklet';
import { addToWorklet } from './tonejs_fixed/WorkletGlobalScope';
		addToWorklet(singleIOProcess);

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

//create the Syrinx Membrane Effect -- it has to be an effect with a source, as the membrane requires an input 
//as well
export class FletcherSmythSyrinxMembrane extends ToneAudioWorklet<ToneAudioNodeOptions> 
{
    readonly name: string = "FletcherSmythSyrinxMembrane";
    
    readonly input: Gain;
	readonly output: Gain;

	constructor();
	constructor(options?: RecursivePartial<ToneAudioNodeOptions>);
	constructor() {
        addToWorklet(singleIOProcess);
        //look at the bitcrusher.....
		super(optionsFromArguments(FletcherSmythSyrinxMembrane.getDefaults(), arguments));

		const options = optionsFromArguments(FletcherSmythSyrinxMembrane.getDefaults(), arguments);

		this.input = new Gain({ context: this.context });
		this.output = new Gain({ context: this.context });
	}

    protected _audioWorkletName(): string {
		return workletName;
	}   

    onReady(node: AudioWorkletNode) {
		connectSeries(this.input, node, this.output);
	}

    dispose(): this {
		super.dispose();
		this.input.dispose();
		this.output.dispose();
		return this;
	}
}


//this is for testing in the svelte main code for now
export function createSynth()
{
    //initialize the noise and start
    var noise = new FletcherSmythSyrinxMembrane();

    //make an autofilter to shape the noise
    var autoFilter = new Tone.AutoFilter(Tone.AutoFilter.getDefaults()).connect(Tone.Master);

    //connect the noise
    noise.connect(autoFilter);

    //start the autofilter LFO
    autoFilter.start()  
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
    var membrane = new FletcherSmythSyrinxMembrane();

    //the combfilter for the waveguide
    let L : number = 0.07; //in m 
    let c : number = 347.4; // in m/s
    let LFreq = c/(2*L);
    let period : number = (0.5) / (LFreq) ; //in seconds
    var delay = new FeedbackCombFilter({ delayTime:period , resonance:0} ); 
    membrane.connect(delay);

    //reflection lowpass filter - need to write my own lp
    var lp = new Tone.Filter(200, "lowpass");
    delay.connect(lp);

    //invert signal
    var flip = new Tone.Negate();
    lp.connect(flip);

    //the combfilter for the waveguide (2nd)
    var delay2 = new FeedbackCombFilter({ delayTime:period , resonance:0} ); 
    lp.connect(delay2);

    ///wall loss attenuation here -- mult. by the coefficient here

    //the feedback loop is here
    var p1 : Gain = new Gain();
    delay2.connect(p1);
   // p1.connect(membrane);
    p1.connect(delay);

    var audioOut = new Gain();
    delay2.connect(audioOut);
    delay.connect(audioOut);

    audioOut.toDestination(); 

}

