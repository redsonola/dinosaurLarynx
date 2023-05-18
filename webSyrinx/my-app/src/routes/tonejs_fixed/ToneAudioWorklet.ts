import { noOp } from "tone/build/esm/core/util/Interface";
import { getWorkletLocalScope } from "./WorkletLocalScope";
import { ToneAudioNode, type ToneAudioNodeOptions } from "tone/build/esm/core/context/ToneAudioNode";


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
	onprocessorerror: any = noOp;

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