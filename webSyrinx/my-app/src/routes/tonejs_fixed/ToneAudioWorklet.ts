import { noOp } from "tone/build/esm/core/util/Interface";
import { getWorkletLocalScope } from "./WorkletLocalScope";
import { ToneAudioNode, type ToneAudioNodeOptions } from "tone/build/esm/core/context/ToneAudioNode";

//This and the other files in tonejs_fixed are modified from Tonejs to fix a bug I found on the platform
//Note: in the next couple weeks, after my deadline -- I'll clean up this fix & report the issue.
//Basically, the code added all the new modules every time the constructor was called via getWorkletGlobalScope
//& I replaced with a local scope call: getWorkletLocalScope() that I wrote
//all worklets I'm using had to be fixed and updated for the fix to work, as the worklets have dependencies, etc.
//& no worklet can call the tonejs version of this constructor & also must use addToWorklet, addProcessor from fixed version
//its not clear why I could instantiate many instances of the same effect without error, but 2 different effects powered by custom
//audio worklets caused the problem -- something under the hood I haven't check out yet
//however, this fixes it for now & will dig in this later when I'm not running against a deadline. or maybe I'll just report the issue as is & hand it off.
//Courtney Brown May 2023

export type ToneAudioWorkletOptions = ToneAudioNodeOptions;

export abstract class ToneAudioWorklet<Options extends ToneAudioWorkletOptions> extends ToneAudioNode<Options> {

	readonly name: string = "ToneAudioWorklet";

	/**
	 * The processing node
	 */
	protected _worklet!: AudioWorkletNode;

	/**
	 * A dummy gain node to create a dummy audio param from
	 */
	private _dummyGain: GainNode;

	/**
	 * A dummy audio param to use when creating Params
	 */
	protected _dummyParam: AudioParam;

	/**
	 * The constructor options for the node
	 */
	protected workletOptions: Partial<AudioWorkletNodeOptions> = {};

	/**
	 * Get the name of the audio worklet
	 */
	protected abstract _audioWorkletName(): string;

	/**
	 * Invoked when the module is loaded and the node is created
	 */
	protected abstract onReady(node: AudioWorkletNode): void;

	/**
	 * Callback which is invoked when there is an error in the processing
	 */
	onprocessorerror: any = (event:any) => {
		console.error("There was an error!");
		console.log(event);
	  };

    protected findProcessingValue()
    {


    }

	constructor(options: Options) {
		super(options);

		const name = this._audioWorkletName();

        let str = getWorkletLocalScope(name);
        let blobUrl = URL.createObjectURL(new Blob([getWorkletLocalScope(name)], { type: "text/javascript" }));

		this._dummyGain = this.context.createGain();
		this._dummyParam = this._dummyGain.gain;

		// Register the processor
		this.context.addAudioWorkletModule(blobUrl, name).then(() => {
			// create the worklet when it's read

			if (!this.disposed) {
				this._worklet = this.context.createAudioWorkletNode(name, this.workletOptions);

				this._worklet.onprocessorerror = this.onprocessorerror.bind(this);
				this.onReady(this._worklet);
			}
		});
	}

	dispose(): this {
		super.dispose();
		this._dummyGain.disconnect();
		if (this._worklet) {
			this._worklet.port.postMessage("dispose");
			this._worklet.disconnect();
		}
		return this;
	}

}