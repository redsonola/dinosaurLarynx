// Copyright 2023 The MediaPipe Authors.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//      http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//MODIFIED by Courtney Brown, 2023
// ++ into typescript

import { DrawingUtils, FaceLandmarker, FilesetResolver, type NormalizedLandmark } from "@mediapipe/tasks-vision";

const vision : any  = await FilesetResolver.forVisionTasks(
    // path/to/wasm/root
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm"

  );
  
// const { FaceLandmarker, FilesetResolver, DrawingUtils } = vision;
   const demosSection = document.getElementById("demos");
   const imageBlendShapes = document.getElementById("image-blend-shapes");
   const videoBlendShapes = document.getElementById("video-blend-shapes");

   let faceLandmarker : FaceLandmarker;
    let runningMode: "IMAGE" | "VIDEO" = "IMAGE";
    let enableWebcamButton: HTMLButtonElement;
    let webcamRunning: Boolean = false;
    const videoWidth = 480;

// Before we can use HandLandmarker class we must wait for it to finish
// loading. Machine Learning models can be large and take a moment to
// get everything needed to run.
async function createFaceLandmarker() {
  const filesetResolver = await FilesetResolver.forVisionTasks(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.3/wasm"
  );
  faceLandmarker = await FaceLandmarker.createFromOptions(filesetResolver, {
    baseOptions: {
      modelAssetPath: `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task`,
      delegate: "GPU"
    },
    outputFaceBlendshapes: true,
    runningMode,
    numFaces: 1
  });
  if(demosSection) //make sure not null
    demosSection.classList.remove("invisible");
}
createFaceLandmarker();

// /********************************************************************
// // Demo 2: Continuously grab image from webcam stream and detect it.
// ********************************************************************/

const video = document.getElementById("webcam") as HTMLVideoElement;
const canvasElement = document.getElementById(
  "output_canvas"
) as HTMLCanvasElement;

const canvasCtx = canvasElement.getContext("2d");

// Check if webcam access is supported.
function hasGetUserMedia() {
  return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
}

// If webcam supported, add event listener to button for when user
// wants to activate it.
if (hasGetUserMedia()) {
  enableWebcamButton = document.getElementById(
    "webcamButton"
  ) as HTMLButtonElement;
  enableWebcamButton.addEventListener("click", enableCam);
} else {
  console.warn("getUserMedia() is not supported by your browser");
}

// Enable the live webcam view and start detection.
function enableCam(event : any) {
  if (!faceLandmarker) {
    console.log("Wait! faceLandmarker not loaded yet.");
    return;
  }

  if (webcamRunning === true) {
    webcamRunning = false;
    enableWebcamButton.innerText = "ENABLE PREDICTIONS";
  } else {
    webcamRunning = true;
    enableWebcamButton.innerText = "DISABLE PREDICTIONS";
  }

  // getUsermedia parameters.
  const constraints = {
    video: true
  };

  // Activate the webcam stream.
  navigator.mediaDevices.getUserMedia(constraints).then((stream) => {
    video.srcObject = stream;
    video.addEventListener("loadeddata", predictWebcam);
  });
}

let lastVideoTime = -1;
let results : any = undefined;
const drawingUtils = new DrawingUtils(canvasCtx as CanvasRenderingContext2D);
async function predictWebcam() {
  const radio = video.videoHeight / video.videoWidth;
  video.style.width = videoWidth + "px";
  video.style.height = videoWidth * radio + "px";
  canvasElement.style.width = videoWidth + "px";
  canvasElement.style.height = videoWidth * radio + "px";
  canvasElement.width = video.videoWidth;
  canvasElement.height = video.videoHeight;
  // Now let's start detecting the stream.
  if (runningMode === "IMAGE") {
    runningMode = "VIDEO";
    await faceLandmarker.setOptions({ runningMode: runningMode });
  }
  let startTimeMs = performance.now();
  if (lastVideoTime !== video.currentTime) {
    lastVideoTime = video.currentTime;
    results = faceLandmarker.detectForVideo(video, startTimeMs);
  }
  if (results.faceLandmarks) {
    for (const landmarks of results.faceLandmarks) {
      drawingUtils.drawConnectors(
        landmarks,
        FACE_LANDMARKS_LIPS_INSIDE,
        //FaceLandmarker.FACE_LANDMARKS_LIPS,
        { color: "#E0E0E0" }
      );
    }
  }
  //drawBlendShapes(videoBlendShapes as HTMLElement, results.faceBlendshapes);

  // Call this function again to keep predicting when the browser is ready.
  if (webcamRunning === true) {
    window.requestAnimationFrame(predictWebcam);
  }
}

function drawBlendShapes(el: HTMLElement, blendShapes: any[]) {
  if (!blendShapes.length) {
    return;
  }

  console.log(blendShapes[0]);
  
  let htmlMaker = "";
  blendShapes[0].categories.map((shape: { displayName: any; categoryName: any; score: string | number; }) => {
    htmlMaker += `
      <li class="blend-shapes-item">
        <span class="blend-shapes-label">${
          shape.displayName || shape.categoryName
        }</span>
        <span class="blend-shapes-value" style="width: calc(${
          +shape.score * 100
        }% - 120px)">${(+shape.score).toFixed(4)}</span>
      </li>
    `;
  });

  el.innerHTML = htmlMaker;
}

//****** Courtney Brown Code 2023 */

/** Landmarks for lips */
export const FACE_LANDMARKS_LIPS_OUTSIDE: any[] = [
  {start: 61, end: 146},  {start: 146, end: 91},  {start: 91, end: 181},
  {start: 181, end: 84},  {start: 84, end: 17},   {start: 17, end: 314},
  {start: 314, end: 405}, {start: 405, end: 321}, {start: 321, end: 375},
  {start: 375, end: 291}, {start: 61, end: 185},  {start: 185, end: 40},
  {start: 40, end: 39},   {start: 39, end: 37},   {start: 37, end: 0},
  {start: 0, end: 267},   {start: 267, end: 269}, {start: 269, end: 270},
  {start: 270, end: 409}, {start: 409, end: 291}
];

export const FACE_LANDMARKS_LIPS_INSIDE: any[] = [
  {start: 78, end: 95},
{start: 95, end: 88},   {start: 88, end: 178},  {start: 178, end: 87},
{start: 87, end: 14},   {start: 14, end: 317},  {start: 317, end: 402},
{start: 402, end: 318}, {start: 318, end: 324}, {start: 324, end: 308},
{start: 78, end: 191},  {start: 191, end: 80},  {start: 80, end: 81},
{start: 81, end: 82},   {start: 82, end: 13},   {start: 13, end: 312},
{start: 312, end: 311}, {start: 311, end: 310}, {start: 310, end: 415},
{start: 415, end: 308} ];

//print mouth landmarks values to console
function printMouthLandmarks( landmarks?: NormalizedLandmark[], connections?: any[]) : void {
  if (!landmarks) {
    return;
  }
  const mouthLandmarks = landmarks.filter((landmark, index) => {
    return FACE_LANDMARKS_LIPS_OUTSIDE.some((item) => {
      return item.start === index || item.end === index;
    });
  });
  console.log(mouthLandmarks);
}
