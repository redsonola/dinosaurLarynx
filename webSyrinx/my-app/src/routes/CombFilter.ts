
//import * as Tone from 'tone';
import { workletName } from "./CombDelayWorklet.worklet";
import { Effect, type EffectOptions } from 'tone/build/esm/effect/Effect';
import { ToneAudioWorklet, type ToneAudioWorkletOptions } from "./tonejs_fixed/ToneAudioWorklet";
import type { NormalRange, Time } from "tone/build/esm/core/type/Units";
import { connectSeries } from "tone/build/esm/core/context/ToneAudioNode";
import { singleIOProcess } from './tonejs_fixed/SingleIOProcessor.worklet';
import { addToWorklet } from './tonejs_fixed/WorkletGlobalScope';
import type { RecursivePartial } from 'tone/build/esm/core/util/Interface';
import { Param } from "tone/build/esm/core/context/Param";
import { optionsFromArguments, type TimeClass, Gain } from "tone";
import type { Positive } from "tone/build/esm/core/type/Units";
//import { delayLine } from "./tonejs_fixed/DelayLine.worklet"


export interface CombFilterEffectOptions extends EffectOptions {
	delayTime: Time;
}

//effect wrapper for feedback delay, perhaps will allow cycles? -- need to move these classes to separate files
export class CombFilterEffect extends Effect<CombFilterEffectOptions> {

	readonly name: string = "CombFilter";

	/**
	 * The amount of delay of the comb filter.
	 */
	readonly delayTime: Param<"time">;

	/**
	 * The node which does the bit crushing effect. Runs in an AudioWorklet when possible.
	 */
	private _combWorklet: CombFilterWorklet;

	constructor(delayTime?: Time);
	constructor(options?: RecursivePartial<CombFilterEffectOptions>);
	constructor() {
		super(optionsFromArguments(CombFilterEffect.getDefaults(), arguments, ["delayTime"]));
		const options = optionsFromArguments(CombFilterEffect.getDefaults(), arguments, ["delayTime"]);

		this._combWorklet = new CombFilterWorklet;
        ({
			context: this.context,
			delayTime: options.delayTime,
		});
		// connect it up
		this.connectEffect(this._combWorklet);

		this.delayTime = this._combWorklet.delayTime;
    }

	static getDefaults(): CombFilterEffectOptions {
        let defaultTime : Time = 0.05;
		return Object.assign(Effect.getDefaults(), {
            delayTime: defaultTime,
		});
	}

	dispose(): this {
		super.dispose();
		this._combWorklet.dispose();
		return this;
	}
}

export interface CombFilterWorkletOptions extends ToneAudioWorkletOptions {
	delayTime: Time;
}

export class CombFilterWorklet extends ToneAudioWorklet<CombFilterWorkletOptions> 
{
    readonly name: string = "FletcherSmythSyrinxMembrane";
    
    readonly input: Gain;
	readonly output: Gain;

    /**
	 * The amount of delay of the comb filter.
	 */
	readonly delayTime: Param<"time">;

	constructor(pG?: Positive);
	constructor(options?: RecursivePartial<CombFilterWorkletOptions>);
	constructor() {
        addToWorklet(singleIOProcess);
        //addToWorklet(delayLine);
		super(optionsFromArguments(CombFilterWorklet.getDefaults(), arguments));
		const options = optionsFromArguments(CombFilterWorklet.getDefaults(), arguments);

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
	}

    static getDefaults(): CombFilterWorkletOptions {
        let defaultTime : Time = 0.05;
		return Object.assign(ToneAudioWorklet.getDefaults(), {
			delayTime: defaultTime,
		});
	}

    protected _audioWorkletName(): string {
		return workletName;
	}   

    onReady(node: AudioWorkletNode) {
		connectSeries(this.input, node, this.output);
        const dT = node.parameters.get("delayTime") as AudioParam;
		this.delayTime.setParam(dT);
	}

    dispose(): this {
		super.dispose();
		this.input.dispose();
		this.output.dispose();
        this.delayTime.dispose(); 
		return this;
	}
}
//-----------------------------------------------------------------------