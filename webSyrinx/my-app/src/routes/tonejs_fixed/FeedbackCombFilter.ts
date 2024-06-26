import { Gain } from 'tone';
import { Param } from "tone";
import { connectSeries, ToneAudioNode, type ToneAudioNodeOptions } from "tone/build/esm/core/context/ToneAudioNode";
import type { NormalRange, Time } from "tone/build/esm/core/type/Units";
import { optionsFromArguments } from "tone";
import { readOnly } from "tone/build/esm/core/util/Interface";
import { ToneAudioWorklet } from "./ToneAudioWorklet";
import { workletName } from "./FeedbackCombFilter.worklet";
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';
import { singleIOProcess } from './SingleIOProcessor.worklet'
import { addToWorklet } from './WorkletGlobalScope';

export interface FeedbackCombFilterOptions extends ToneAudioNodeOptions {
	delayTime: Time;
	resonance: NormalRange;
}

/**
 * Comb filters are basic building blocks for physical modeling. Read more
 * about comb filters on [CCRMA's website](https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html).
 * 
 * This comb filter is implemented with the AudioWorkletNode which allows it to have feedback delays less than the 
 * Web Audio processing block of 128 samples. There is a polyfill for browsers that don't yet support the 
 * AudioWorkletNode, but it will add some latency and have slower performance than the AudioWorkletNode. 
 * @category Component
 */
export class FeedbackCombFilter extends ToneAudioWorklet<FeedbackCombFilterOptions> {

	readonly name = "FeedbackCombFilter";

	/**
	 * The amount of delay of the comb filter.
	 */
	readonly delayTime: Param<"time">;

	/**
	 * The amount of feedback of the delayed signal.
	 */
	readonly resonance: Param<"normalRange">;

	readonly input: Gain;
	readonly output: Gain;

	/**
	 * @param delayTime The delay time of the filter.
	 * @param resonance The amount of feedback the filter has.
	 */
	constructor(delayTime?: Time, resonance?: NormalRange);
	constructor(options?: RecursivePartial<FeedbackCombFilterOptions>);
	constructor() {
		addToWorklet(singleIOProcess);
		super(optionsFromArguments(FeedbackCombFilter.getDefaults(), arguments));
		const options = optionsFromArguments(FeedbackCombFilter.getDefaults(), arguments);

		this.input = new Gain({ context: this.context });
		this.output = new Gain({ context: this.context });

		this.delayTime = new Param<"time">({
			context: this.context,
			value: options.delayTime,
			units: "time",
			minValue: 0,
			maxValue: 1,
			param: this._dummyParam,
			swappable: true,
		});

		this.resonance = new Param<"normalRange">({
			context: this.context,
			value: options.resonance,
			units: "normalRange",
			param: this._dummyParam,
			swappable: true,
		});

		//readOnly(this, ["resonance", "delayTime"]);
	}

	protected _audioWorkletName(): string {
		return workletName;
	}

	/**
	 * The default parameters
	 */
	static getDefaults(): FeedbackCombFilterOptions {
		return Object.assign(ToneAudioNode.getDefaults(), {
			delayTime: 0.1,
			resonance: 0.0,
		});
	}

	onReady(node: AudioWorkletNode) {
		connectSeries(this.input, node, this.output);
		const delayTime = node.parameters.get("delayTime") as AudioParam;
		this.delayTime.setParam(delayTime);
		const feedback = node.parameters.get("feedback") as AudioParam;
		this.resonance.setParam(feedback);
	}

	dispose(): this {
		super.dispose();
		this.input.dispose();
		this.output.dispose();
		this.delayTime.dispose();
		this.resonance.dispose();
		return this;
	}
}
