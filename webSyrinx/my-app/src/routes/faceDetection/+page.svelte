<!-- Copyright 2023 The MediaPipe Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. -->
  <script>  
  import("./mouthTracking");
  </script>

<svelte:head>
  <meta charset="utf-8">
  <meta http-equiv="Cache-control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <title>Face Landmarker</title>


  <!-- <link href="https://unpkg.com/material-components-web@latest/dist/material-components-web.min.css" rel="stylesheet"> -->
  <!-- <script src="https://unpkg.com/material-components-web@latest/dist/material-components-web.min.js"></script> -->

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

</svelte:head>
<body>
  <h1>Face landmark detection using the MediaPipe FaceLandmarker task</h1>

  <!-- <section id="demos"></section> class="invisible"> -->
  <section id="demos">
    <h2>Demo: Webcam continuous face landmarks detection</h2>
    <p>Hold your face in front of your webcam to get real-time face landmarker detection. <br/>Click <b>enable webcam</b> below and grant access to the webcam if prompted.</p>

    <div id="liveView" class="videoView">
      <button id="webcamButton" class="mdc-button mdc-button--raised">
        <span class="mdc-button__ripple"></span>
        <span class="mdc-button__label">ENABLE WEBCAM</span>
      </button>
      <div style="position: relative;">
        <video id="webcam" style="position: abso" autoplay playsinline><track kind="captions"></video>
        <canvas class="output_canvas" id="output_canvas" style="position: absolute; left: 0px; top: 0px;"></canvas>
      </div>
    </div>
    <div class="blend-shapes">
      <ul class="blend-shapes-list" id="video-blend-shapes"></ul>
    </div>
  </section>
</body>
