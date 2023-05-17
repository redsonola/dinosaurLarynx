import * as Tone from 'tone';
import { ToneBufferSource } from 'tone';
import type { Time } from 'tone/build/esm/core/type/Units';
import { Source, type SourceOptions } from 'tone/build/esm/source/Source';
import { SyrinxMembrane } from './SyrinxMembraneSynthesis';
// import { Monophonic, type MonophonicOptions } from 'tone/build/esm/instrument/Monophonic';
//import { Source, type SourceOptions } from 'tone/tone/source/Source';

//mediapipe face-tracking
//NOTE: https://codepen.io/mediapipe-preview/pen/OJBVQJm


//TODO: get this from audio options or something
var SAMPLERATE = 44100;
var CHANNEL_COUNT = 2;


//default syrinx class
export class SyrinxMembraneSource<T extends SourceOptions> extends Source<T>
{
	/**
	 * Protected reference to the source
	 */
	protected _source: Tone.ToneBufferSource | null = null;

    protected _start(time: Tone.Unit.Time, offset?: Tone.Unit.Time | undefined, duration?: Tone.Unit.Time | undefined): void {
        throw new Error('Method not implemented.');
    }
    protected _stop(time: Tone.Unit.Time): void {
        throw new Error('Method not implemented.');
    }
    protected _restart(time: number, offset?: Tone.Unit.Time | undefined, duration?: Tone.Unit.Time | undefined): void {
        throw new Error('Method not implemented.');
    }  
    name = "Syrinx Membrane Source";
}

//implements Fletcher(1988)/Smyth(2002) model
export class smFletcherSmyth<T extends SourceOptions>  extends SyrinxMembraneSource<T>
{
    readonly name = "Fletcher Smyth Syrinx Membrane Model";

    /**
	 * The fadeIn time of the amplitude envelope.
	 */
	protected _fadeIn!: Time;

	/**
	 * The fadeOut time of the amplitude envelope.
	 */
	protected _fadeOut!: Time;

	/**
	 * buffer for the syrinx membrane mechanism output -- wraps the class which does the math, etc.
	 */
    protected _syrinxBuffer: SyrinxMembraneBuffer = new SyrinxMembraneBuffer(); 

    /**
	 * internal start method
	 */
	/**
	 * internal start method
	 */
	protected _start(time?: Time): void {
		const buffer = this._syrinxBuffer.getBuffer();
		this._source = new ToneBufferSource({
			url: buffer,
			context: this.context,
			fadeIn: this._fadeIn,
			fadeOut: this._fadeOut,
			loop: true,
			onended: () => this.onstop(this),
		}).connect(this.output);
		this._source.start(this.toSeconds(time), Math.random() * (buffer.duration - 0.001));
	}

    static getDefaults(): SourceOptions {
		return Object.assign(Source.getDefaults(), {
			fadeIn: 0,
			fadeOut: 0,
			playbackRate: 1,
		});
	}

	/**
	 * internal stop method
	 */
	protected _stop(time?: Time): void {
		if (this._source) {
			this._source.stop(this.toSeconds(time));
			this._source = null;
		}
	}

    /**
	 * The fadeOut time of the amplitude envelope.
	 */
	get fadeOut(): Time {
		return this._fadeOut;
	}
	set fadeOut(time) {
		this._fadeOut = time;
		if (this._source) {
			this._source.fadeOut = this._fadeOut;
		}
	}

	protected _restart(time?: Time): void {
		// TODO could be optimized by cancelling the buffer source 'stop'
		this._stop(time);
		this._start(time);
	}

    /**
	 * Clean up.
	 */
	dispose(): this {
		super.dispose();
		if (this._source) {
			this._source.disconnect();
		}
		return this;
	}
};
    
//--------------------
// THE SYRINX MEMBRANE BUFFERS
//--------------------

// Noise buffer stats
const BUFFER_LENGTH = SAMPLERATE * 5;
const NUM_CHANNELS = CHANNEL_COUNT;

/**
 * The cached noise buffers
 */
interface SyrinxMembraneCache {
	[key: string]: Tone.ToneAudioBuffer | null;
}

/**
 * Cache the noise buffers
 */
const _syrinxCache: SyrinxMembraneCache = {
	membraneBuf: null,
};

//I assume this is where the math happens, sigh.
class SyrinxMembraneBuffer
{
    protected membrane : SyrinxMembrane = new SyrinxMembrane();
    public getBuffer() : Tone.ToneAudioBuffer 
    {
		if (!_syrinxCache.membraneBuf) {
			const buffer: Float32Array[] = [];
			for (let channelNum = 0; channelNum < NUM_CHANNELS; channelNum++) {
				const channel = new Float32Array(BUFFER_LENGTH);
				buffer[channelNum] = channel;
				let lastOut = 0.0;
				for (let i = 0; i < BUFFER_LENGTH; i++) {
					const white = Math.random() * 2 - 1;
					channel[i] = (lastOut + (0.02 * white)) / 1.02;
					lastOut = channel[i];
					channel[i] *= 3.5; // (roughly) compensate for gain
				}
			}
			_syrinxCache.membraneBuf = new Tone.ToneAudioBuffer().fromArray(buffer);
		}
		return _syrinxCache.membraneBuf;
	}
};


//this is for testing in the svelte main code for now
export function createSynth()
{
    //initialize the noise and start
    var noise = new smFletcherSmyth(smFletcherSmyth.getDefaults()).start();

    //make an autofilter to shape the noise
    var autoFilter = new Tone.AutoFilter(Tone.AutoFilter.getDefaults()).connect(Tone.Master);

    //connect the noise
    noise.connect(autoFilter);

    //start the autofilter LFO
    autoFilter.start()  
}



