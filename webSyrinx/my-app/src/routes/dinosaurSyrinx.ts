import * as Tone from 'tone';
import { Gain, ToneBufferSource, optionsFromArguments } from 'tone';
import type { Time } from 'tone/build/esm/core/type/Units';
import { Source, type SourceOptions } from 'tone/build/esm/source/Source';
import { Effect, type EffectOptions } from 'tone/build/esm/effect/Effect';
import { ToneAudioWorklet } from "tone/build/esm/core/worklet/ToneAudioWorklet"
import { workletName } from "./SyrinxMembraneWorklet.worklet";
import { connectSeries, ToneAudioNode, type ToneAudioNodeOptions } from "tone/build/esm/core/context/ToneAudioNode";
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';




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



