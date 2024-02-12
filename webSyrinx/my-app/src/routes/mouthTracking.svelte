<script>

  	import("./faceDetection/mouthTracking");

</script>

	<style>
		@use "@material";
	body {
	  font-family: helvetica, arial, sans-serif;
	  margin: 2em;
	  color: #3d3d3d;
	  --mdc-theme-primary: #007f8b;
	  --mdc-theme-on-primary: #f1f3f4;
	}
	
	h1 {
	  font-style: italic;
	  color: #ff6f00;
	  color: #007f8b;
	}
	
	h2 {
	  clear: both;
	}
	
	em {
	  font-weight: bold;
	}
	
	video {
	  clear: both;
	  display: block;
	  transform: rotateY(180deg);
	  -webkit-transform: rotateY(180deg);
	  -moz-transform: rotateY(180deg);
	}

	.setupButtonInvisible
	{
	  	opacity: 0.0;
		z-index: 0.0;
	}

	.setupButtonVisible
	{
	  	opacity: 1.0;
		z-index: 100.0;
	}
	
	section {
	  opacity: 1;
	  transition: opacity 500ms ease-in-out;
	}
	
	header,
	footer {
	  clear: both;
	}
	
	.removed {
	  display: none;
	}
	
	.invisible {
	  opacity: 0.2;
	}
	
	.note {
	  font-style: italic;
	  font-size: 130%;
	}
	
	.videoView,
	.detectOnClick,
	.blend-shapes {
	  position: relative;
	  float: left;
	  width: 48%;
	  margin: 2% 1%;
	  cursor: pointer;
	}
	
	.videoView p,
	.detectOnClick p {
	  position: absolute;
	  padding: 5px;
	  background-color: #007f8b;
	  color: #fff;
	  border: 1px dashed rgba(255, 255, 255, 0.7);
	  z-index: 2;
	  font-size: 12px;
	  margin: 0;
	}
	
	.highlighter {
	  background: rgba(0, 255, 0, 0.25);
	  border: 1px dashed #fff;
	  z-index: 1;
	  position: absolute;
	}
	
	.canvas {
	  z-index: 1;
	  position: absolute;
	  pointer-events: none;
	}
	
	.output_canvas {
	  transform: rotateY(180deg);
	  -webkit-transform: rotateY(180deg);
	  -moz-transform: rotateY(180deg);
	}
	
	.detectOnClick {
	  z-index: 0;
	}
	
	.detectOnClick img {
	  width: 100%;
	}
	
	.blend-shapes-item {
	  display: flex;
	  align-items: center;
	  height: 20px;
	}
	
	.blend-shapes-label {
	  display: flex;
	  width: 120px;
	  justify-content: flex-end;
	  align-items: center;
	  margin-right: 4px;
	}
	
	.blend-shapes-value {
	  display: flex;
	  height: 16px;
	  align-items: center;
	  background-color: #007f8b;
	}
	  </style>
	
	<!-- </svelte:head> --
	<div class="faceTrackingModule">

	  <h1>Face landmark detection using the MediaPipe FaceLandmarker task</h1>

	
	  <!-- <section id="demos"></section> class="invisible"> mdc-button mdc-button--raised  -->
	  <br />

	  <section id="demos">
		<button id="webcamButton" class="z-index: 100.0;" >
			Enable webcam and control syrinx tension via mouth-tracking
					  </button>

					  <button id="setupMouthTracking" class="setupButtonInvisible">
						Adjust Mouth-Tracking Response
					</button>

		<!-- <h2>Demo: Webcam continuous face landmarks detection</h2>
		<p>Hold your face in front of your webcam to get real-time face landmarker detection. <br/>Click <b>enable webcam</b> below and grant access to the webcam if prompted.</p> -->
	
		<div id="liveView" class="videoView">
		  <div style="position: center;">
			<video id="webcam" style="position: absolute" autoplay playsinline><track kind="captions"></video>
			<canvas class="output_canvas" id="output_canvas" style="position: absolute; left: 0px; top: 0px;"></canvas>

		  </div>

		</div>

		<div class="blend-shapes">
		  <ul class="blend-shapes-list" id="video-blend-shapes"></ul>
		</div>


		<div id="inputValuesForTracking" style="opacity:0; background:rgb(255, 255, 255)">
			<h3 style="position:center;">Configure Mouth-Tracking Sounding Response </h3>

			<p><b>Instructions:</b> Please adjust your mouth to the desired min and max positions. If far outside the range of 0.0-1.0 or you are experiencing clipping, etc., then adjust the min and max values: <br />
				1. Click Reset to reset/clear the currently recorded min and max values and initialize.<br />
				2. Move your mouth to closed and wide positions. Make sure you can blow a stream of air into the microphone to create sound in all mouth positions. Note that it is difficult to open the mouth very wide and accelerate air. If you need, you can click reset again. <br />
				4. Click 'Fill Mouth Values' to update the values using the recorded min and max from mouthtracking OR enter in your own values.<br />
				5. Submit your changes to adjust the scale values and sounding response.<br /></p>

				<button id="resetRecordedMouthMinimumsAndMaximums"> Reset Recorded Minuminums and Maximums for Mouth Wideness/Openness </button> <br />
				<button id="editMouthValueAutoFill"> Fill values with Raw Minimums and Maximums for Mouth Wideness/Openness  </button> <br />
				<button id="submitEditMouthConfig"> Update Mouth Tracking Scalin for Mouth Wideness/Openness</button> <br />

			<!--	<button id="resetRecordedMouthMinimumsAndMaximumsMic"> Reset Recorded Minuminums and Maximums for Microphone Input </button> <br />
				<button id="editMouthValueAutoFillMic"> Fill values with Raw Minimums and Maximums for Microphone Input   </button> <br />
				<button id="submitEditMouthConfigMic"> Update Mouth Tracking Scalin for for Microphone Input </button> <br /> -->

			<label id="outputMouthValue"></label><br/>

			<h3>Edit Mouth Tracking Wideness/Openness Scaling - Controls Tension </h3>

			Least Wide:<input type="text" id="leastWideInput"  value="0" /><br />
			Most Wide:<input type="text" id="mostWideInput"  value="0" /><br />
			Least Open:<input type="text" id="leastOpenInput"  value="0" /><br />
			Most Open:<input type="text" id="mostOpenInput" value="0" /><br /><br /> 
			<label id="mouthConfigStatus">Status: Ready to Config</label><br/>

			 <h3>Edit Microphone Response for Blowing - Controls Air Pressure </h3>

			<label id="micConfigStatus">Status: Ready to Config</label><br/> 
			Enter in New Mic Max:<input type="text" id="micMax"  value="0" /><br />

			<button id="resetMicMax"> Reset Loudest Recorded to 0.0 </button> <br />
			<button id="micAutoFill"> Fill values with current Microphone Max</button> <br />
			<button id="submitMicMax"> Update Max Microphone Volume</button> <br />

			<br />
<br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br />
			
		</div>

	  </section>
	



