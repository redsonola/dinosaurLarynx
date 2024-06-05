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
import { m, micScaling, curMicIn, curMaxMicIn, tens, trachealSyrinx } from "../dinosaurSyrinx" //importing from here, too
import {mouthDataFile, wideMin, wideMax, mouthAreaMin, mouthAreaMax, setMouthWideMin, setMouthAreaMax, setMouthAreaMin, setMouthWideMax} from './mouthMeasures'; //things I want to import

// const vision : any  = await FilesetResolver.forVisionTasks(
//     // path/to/wasm/root
//     "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm"

//   );
  
// const { FaceLandmarker, FilesetResolver, DrawingUtils } = vision;
   const demosSection = document.getElementById("demos");
   const imageBlendShapes = document.getElementById("image-blend-shapes");
   const videoBlendShapes = document.getElementById("video-blend-shapes");

   let faceLandmarker : FaceLandmarker;
    let runningMode: "IMAGE" | "VIDEO" = "IMAGE";
    let enableWebcamButton: HTMLButtonElement;

    let micMaxInput : HTMLInputElement = document.getElementById("micMax") as HTMLInputElement; // initialize submit button for mouth params
    let micConfigStatus : HTMLLabelElement = document.getElementById("micConfigStatus") as HTMLLabelElement; // status for mic config
    let resetMicMax : HTMLButtonElement = document.getElementById("resetMicMax") as HTMLButtonElement; // initialize submit button for mouth params
    let micAutoFill : HTMLButtonElement = document.getElementById("micAutoFill") as HTMLButtonElement; // initialize submit button for mouth params
    let submitMicMax : HTMLButtonElement = document.getElementById("submitMicMax") as HTMLButtonElement; // initialize submit button for mouth params



    let inputValuesForTrackingSection: HTMLElement;
    let outputMouthValue : HTMLLabelElement = document.getElementById("outputMouthValue") as HTMLLabelElement; // initialize output label
    let editMouthValueAutoFill : HTMLButtonElement = document.getElementById("editMouthValueAutoFill") as HTMLButtonElement; // initialize fill button for mouth params
    let submitEditMouthConfig : HTMLButtonElement = document.getElementById("submitEditMouthConfig") as HTMLButtonElement; // initialize submit button for mouth params

    let mouthWideMin : HTMLInputElement = document.getElementById("leastWideInput") as HTMLInputElement; // initialize submit button for mouth params
    let mouthWideMax : HTMLInputElement = document.getElementById("mostWideInput") as HTMLInputElement; // initialize submit button for mouth params
    let mouthOpenMin : HTMLInputElement = document.getElementById("leastOpenInput") as HTMLInputElement; // initialize submit button for mouth params
    let mouthOpenMax : HTMLInputElement = document.getElementById("mostOpenInput") as HTMLInputElement; // initialize submit button for mouth params
    let resetRecordedMouthMinimumsAndMaximums : HTMLButtonElement = document.getElementById("resetRecordedMouthMinimumsAndMaximums") as HTMLButtonElement; // initialize submit button for mouth params
    let mouthConfigStatus : HTMLLabelElement = document.getElementById("mouthConfigStatus") as HTMLLabelElement; // status for mouth tracking config
  
    let webcamRunning: Boolean = false;
    export const videoWidth = 480;

    let configMouthTrackingButton: HTMLButtonElement;

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
    outputFaceBlendshapes: false,
    runningMode,
    numFaces: 1
  });
  // if(demosSection) //make sure not null
  //   demosSection.classList.remove("invisible");
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
  configMouthTrackingButton = document.getElementById(
    "setupMouthTracking"
    ) as HTMLButtonElement;
    configMouthTrackingButton.addEventListener("click", showInputValuesSection);
    editMouthValueAutoFill.addEventListener("click", fillMouthInputValues);
    resetRecordedMouthMinimumsAndMaximums.addEventListener("click", resetMouthMinMax);
    submitEditMouthConfig.addEventListener("click", updateWidenessOpennessScaling);
    resetMicMax.addEventListener("click", resetMicMinMax );
    submitMicMax.addEventListener("click", submitMicMaxFunc);
    micAutoFill.addEventListener("click", micAutoFillSubmit);

    
    inputValuesForTrackingSection = document.getElementById("inputValuesForTracking") as HTMLElement;
} else {
  console.warn("getUserMedia() is not supported by your browser");
}

// Enable the live webcam view and start detection.
function enableCam(event : any) {
  trachealSyrinx(); //start the sound just in case.
  if (!faceLandmarker) {
    console.log("Wait! faceLandmarker not loaded yet.");
    return;
  }

  if (webcamRunning === true) {
    webcamRunning = false;
    enableWebcamButton.innerText = "Enable Mouth Tracking Syrinx Control";
    configMouthTrackingButton.className = "setupButtonInvisible";
    configMouthTrackingButton.style.opacity = "0";
    video.style.opacity = "0";
    canvasElement.style.opacity = "0";
    inputValuesForTrackingSection.style.opacity = "0";
    configMouthTrackingButton.innerText = "Adjust Mouth-Tracking Response";



  } else {
    webcamRunning = true;
    enableWebcamButton.innerText = "Disable Mouth Tracking Syrinx Control";
    video.style.opacity = "1";
    canvasElement.style.opacity = "1";
    inputValuesForTrackingSection.style.opacity = "0";
    configMouthTrackingButton.innerText = "Adjust Mouth-Tracking Response";

  }

  // getUsermedia parameters
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

  //center
  canvasElement.style.left = (videoWidth/2) + "px";
  video.style.left = (videoWidth/2) + "px";

  let configTop = (canvasElement.height*.9 ) ;
  //console.log("configTop: " + configTop);

  //place config button after video
  configMouthTrackingButton.style.position = "relative";
  configMouthTrackingButton.style.top = configTop + "px";
  configMouthTrackingButton.style.left = 0 + "px";
  inputValuesForTrackingSection.style.position = "relative";
  inputValuesForTrackingSection.style.top = canvasElement.height + "px";
  inputValuesForTrackingSection.style.left = 0 + "px";

  
  if( results && webcamRunning === true)
  {
    configMouthTrackingButton.className = "setupButtonVisible";
    configMouthTrackingButton.style.opacity = "1";
  }

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
    printMouthLandmarks(results.faceLandmarks);
    for (const landmarks of results.faceLandmarks) {
      drawingUtils.drawConnectors(
        landmarks,
        FACE_LANDMARKS_LIPS_OPENNESS_MEASURES,
        { color: "#E0E0E0" }
      );
      drawingUtils.drawConnectors(
        landmarks,
        FACE_LANDMARKS_LIPS_INSIDE,
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

  //console.log(blendShapes[0]);
  
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

//DOING: find the landmarks that correspond to the center of the lips and corners of the mouth and then compare those.


/** Landmarks for lips */
export const FACE_LANDMARKS_LIPS_OUTSIDE: any[] = [
  {start: 61, end: 146},  {start: 146, end: 91},  {start: 91, end: 181},
  {start: 181, end: 84},  {start: 84, end: 17},   {start: 17, end: 314},
  {start: 314, end: 405}, {start: 405, end: 321}, {start: 321, end: 375},
  {start: 375, end: 291}, {start: 61, end: 185},  {start: 185, end: 40},
  {start: 40, end: 39},   {start: 39, end: 37},   {start: 37, end: 0},
  {start: 0, end: 267},   {start: 267, end: 269}, {start: 269, end: 270},
  {start: 270, end: 409}, {start: 409, end: 291}
]; //draw these to see what they look like


/** Landmarks for lips */
export const FACE_LANDMARKS_LIPS_OUTSIDE_BOTTOM: any[] = [
  {start: 61, end: 146},  {start: 146, end: 91},  {start: 91, end: 181},
  {start: 181, end: 84},  {start: 84, end: 17},   {start: 17, end: 314},
  {start: 314, end: 405}, {start: 405, end: 321}, {start: 321, end: 375},
  {start: 375, end: 291}, //{start: 61, end: 185},  {start: 185, end: 40},
  // {start: 40, end: 39},   {start: 39, end: 37},   {start: 37, end: 0},
  // {start: 0, end: 267},   {start: 267, end: 269}, {start: 269, end: 270},
  // {start: 270, end: 409}, {start: 409, end: 291}
]; //draw these to see what they look like

/** Landmarks for lips */
export const FACE_LANDMARKS_LIPS_OUTSIDE_TOP: any[] = [
  {start: 61, end: 185},  {start: 185, end: 40},
   {start: 40, end: 39},   {start: 39, end: 37},   {start: 37, end: 0},
   {start: 0, end: 267},   {start: 267, end: 269}, {start: 269, end: 270},
   {start: 270, end: 409}, {start: 409, end: 291}
]; //draw these to see what they look like

//measures mouth wideness more or less
export const FACE_LANDMARKS_MOUTH_WIDENESS: any[] = [
  {start: 61, end: 308}

];

export const FACE_LANDMARKS_LIPS_OPENNESS: any[] = [
  {start: 14, end: 13}];

export const FACE_LANDMARKS_LIPS_OPENNESS_MEASURES: any[] = [
  {start: 61, end: 308},
  {start: 14, end: 13}
];


//TODO: test until find a good marker for mouth openness
// export const FACE_LANDMARKS_LIPS_OPENNESS_OUTSIDE: any[] = [
//   {start: 17, end: 0 } ];



export const FACE_LANDMARKS_LIPS_INSIDE: any[] = [
  {start: 78, end: 95},
{start: 95, end: 88},   {start: 88, end: 178},  {start: 178, end: 87},
{start: 87, end: 14},   {start: 14, end: 317},  {start: 317, end: 402},
{start: 402, end: 318}, {start: 318, end: 324}, {start: 324, end: 308},
{start: 78, end: 191},  {start: 191, end: 80},  {start: 80, end: 81},
{start: 81, end: 82},   {start: 82, end: 13},   {start: 13, end: 312},
{start: 312, end: 311}, {start: 311, end: 310}, {start: 310, end: 415},
{start: 415, end: 308} ];


//TODO: refactor this out jesus christ
function distance(pt1: NormalizedLandmark, pt2:NormalizedLandmark)
{
  return Math.sqrt((pt1.x - pt2.x)*(pt1.x - pt2.x) + (pt1.y - pt2.y)*(pt1.y - pt2.y));
}

//try normalizing by depth so that it is more invariant to distance from camera
function depthNormalizedDistance(pt1: NormalizedLandmark, pt2:NormalizedLandmark)
{
    console.log("z: " + pt1.z + "," + pt2.z)
    let p1 = { x: pt1.x, y: pt1.y, z: pt1.z};
    let p2 = { x: pt2.x, y: pt2.y, z: pt2.z};
    // if(pt1.z != 0)  {p1.x = p1.x / (p1.z);}
    // if(pt2.z != 0)  {p2.y = p1.y / (p2.z);}
    let dist = distance(p1, p2);
    let normDepth = scale(pt1.z, -0.03, 0.1);

    if(normDepth != 0)
    {
        dist = dist * (1-normDepth);
    }
    return dist;
}

function scale(inSig:number, min:number, max:number)
{
  return (inSig - min)/(max - min);
}

//I didn't know the formula to calculate the area of a polygon so I found this on stackoverflow
//https://stackoverflow.com/questions/16285134/calculating-polygon-area
function calcPolygonArea(vertices: {x:number, y:number}[]) {
  var total = 0;

  for (var i = 0, l = vertices.length; i < l; i++) {
    var addX = vertices[i].x;
    var addY = vertices[i == vertices.length - 1 ? 0 : i + 1].y;
    var subX = vertices[i == vertices.length - 1 ? 0 : i + 1].x;
    var subY = vertices[i].y;

    total += (addX * addY * 0.5);
    total -= (subX * subY * 0.5);
  }

  return Math.abs(total);
}

function updateMouthArea(areaMouthLandmarks:any[]) : number
{
  let vertices:{x:number, y:number}[] = [];
  for(let i=0; i<areaMouthLandmarks.length; i++)
  {
    vertices.push({x: areaMouthLandmarks[i].x, y: areaMouthLandmarks[i].y});
  }
  return calcPolygonArea(vertices);
}

function updateMouthAreaDepthNormalized(areaMouthLandmarks:any[]) : number
{
  let vertices:{x:number, y:number}[] = [];
  for(let i=0; i<areaMouthLandmarks.length; i++)
  {
    vertices.push({x: areaMouthLandmarks[i].x/(1+areaMouthLandmarks[i].z), y: areaMouthLandmarks[i].y/(1+areaMouthLandmarks[i].z)});
  }
  return calcPolygonArea(vertices);
}


//min x
//let minMX = 1000;
let minMY = 1000;
//let minrawMX = 1000;
let minrawMY = 1000;

//let maxMX = -1000;
let maxMY = -1000;
//let maxrawMX = -1000;
let maxrawMY = -1000;

//x value -- wideness, but m.y because it replaces the mouse m.y value -- change this
// var xScaleMin = 0.0003;
// var xScaleMax = 0.05;
//var yScaleMin = 0.07;
// var yScaleMax = 0.12;

var minMic = 1000;
var maxMic = -1000;
var softestMic = -1.0;
var loudestMic = 1.0;


let minMouthArea = 1000;
let maxMouthArea = -1000;
var mouthAreaRaw = 0.0;
var mouthArea = 0.0;
var minMouthAreaRaw = 1000;
var maxMouthAreaRaw = -1000;


//print mouth landmarks values to console & update mouth values
function printMouthLandmarks( landmarks?: NormalizedLandmark[][], connections?: any[]) : void {
  if (!landmarks) {
    return;
  }
  let mouthLandmarks = []; 
  let insideMouthLandmarks = [];
  let marks : NormalizedLandmark[] = landmarks[0];
  if( marks )
  {
    for(let i=0; i<FACE_LANDMARKS_LIPS_OPENNESS_MEASURES.length; i++)
    {
      let res : NormalizedLandmark = marks[ FACE_LANDMARKS_LIPS_OPENNESS_MEASURES[i].start ];
      let res2 : NormalizedLandmark = marks[ FACE_LANDMARKS_LIPS_OPENNESS_MEASURES[i].end ];

      mouthLandmarks.push(res);
      mouthLandmarks.push(res2);
    }

    for(let i=0; i<FACE_LANDMARKS_LIPS_INSIDE.length; i++)
    {
      let res : NormalizedLandmark = marks[ FACE_LANDMARKS_LIPS_INSIDE[i].start ];
      let res2 : NormalizedLandmark = marks[ FACE_LANDMARKS_LIPS_INSIDE[i].end ];

      insideMouthLandmarks.push(res);
      insideMouthLandmarks.push(res2);
    }

    let wideness = depthNormalizedDistance(mouthLandmarks[0], mouthLandmarks[1]);
    let openness = depthNormalizedDistance(mouthLandmarks[2], mouthLandmarks[3]);

    //find perimeter of mouth
    mouthAreaRaw = updateMouthAreaDepthNormalized(insideMouthLandmarks); //area of the open mouth

    mouthArea = scale(mouthAreaRaw, mouthAreaMin, mouthAreaMax); 


    //minMouthArea = Math.min(0.1, mouthArea);
    maxMouthArea = Math.max(0, mouthArea);
    //console.log("Mouth Area: " + mouthArea + ", min: "+ minMouthArea + ", max: " + maxMouthArea);

    //note: values are flipped to match the mouse movement. So x is openness and y is wideness
    let wide = scale(wideness, wideMin, wideMax) ;

    //put some guard rails on the values
    m.x = Math.max(0.00000001, m.x);
    m.x = Math.min(1.2, m.x);

            // //put some guard rails on the values -- got rid of this for now
            // m.y = Math.max(0.00000001, m.y);
            // m.y = Math.min(1.2, m.y);

    m.y =  scale(wideness, wideMin, wideMax) ;
    m.y = Math.min(5.0, m.y); 
    m.x = mouthArea//testing mouth area
    m.x = Math.min(5.0, m.x); 
    //console.log("m.y: "+m.y+" wideness: " +wide +" Mouth Area: " + mouthArea + ", min: "+ minMouthArea + ", max: " + maxMouthArea);




    //find min values
    minMouthAreaRaw = Math.min(minMouthAreaRaw, mouthAreaRaw);
    minrawMY = Math.min(minrawMY, wideness);
    //minMX = Math.min(minMX, m.x);
    minMY = Math.min(minMY, m.y);

    //find max values
    maxMouthAreaRaw = Math.max(maxMouthAreaRaw, mouthAreaRaw);
    maxrawMY = Math.max(maxrawMY, wideness);
    //maxMX = Math.max(maxMX, m.x);
    maxMY = Math.max(maxMY, m.y);

    //console.log("wideness: " + m.y + " openness: " + m.x);

    outputMouthValue.innerText = 
    /*
    "Mouth Wideness Scaled: " + m.x +
    "\nMouth Wideness Minimum Recorded Scaled Value: " + minMY +
    "\nMouth Wideness Maximum Recorded Scaled Value: " + maxMY +

    "\n\nMouth Wideness Scaled Raw: " + wideness +  
    "\nMouth Wideness Minimum Recorded Raw Value: " + minrawMY +
    "\nMouth Wideness Minimum Recorded Raw Value: " + maxrawMY +
*/
    "\n\nMouth Openness: " + m.y +
    "\nMouth Openness Minimum Recorded Scaled Value: " + minMouthArea +
    "\nMouth Openness Maximum Recorded Scaled Value: " + maxMouthArea +

    "\n\nMouth Openness Scaled Raw: " + m.y +  
    "\nMouth Openness Minimum Recorded Raw Value: " + minMouthAreaRaw +
    "\nMouth Openness Maximum Recorded Raw Value: " + maxMouthAreaRaw +

    "\n\nVocal tension (After mapping): " + tens + "\n\n";
  } 
}

export function fillMouthInputValues()
{

   mouthWideMin.value = minrawMY.toString();
   mouthWideMax.value = maxrawMY.toString();
   mouthOpenMin.value = minMouthAreaRaw.toString();
   mouthOpenMax.value = maxMouthAreaRaw.toString();

}

export function updateWidenessOpennessScaling()
{
  mouthDataFile.toggleRecording()
  mouthDataFile.addData([wideMin, wideMax, mouthAreaMin, mouthAreaMax]);

  setMouthWideMin(parseFloat(mouthWideMin.value));
  setMouthWideMax(parseFloat(mouthWideMax.value));
  setMouthAreaMin(parseFloat(mouthOpenMin.value));
  setMouthAreaMax(parseFloat(mouthOpenMax.value));  
  mouthConfigStatus.innerText = "Mouth Tracking Minimums and Maximums are updated:\n" +
  "\nMouth Wideness Minimum Recorded Scaled Value: " + wideMin +
  "\nMouth Wideness Maximum Recorded Scaled Value: " + wideMax + "\n\n" +
  "\nMouth Openness Minimum Recorded Scaled Value: " + mouthAreaMin +
  "\nMouth Openness Maximum Recorded Scaled Value: " + mouthAreaMax + "\n\n" ;

  mouthDataFile.toggleRecording(); //only record this small bit of info so far
}

// export function updateMicrophoneScaling()
// {
//   wideMin = parseFloat(mouthWideMin.value);
//   wideMax = parseFloat(mouthWideMax.value);
//   mouthAreaMin = parseFloat(mouthOpenMin.value);
//   mouthAreaMax = parseFloat(mouthOpenMax.value);  
//   mouthConfigStatus.innerText = "Mouth Tracking Minimums and Maximums are updated:\n" +
//   "\nMouth Wideness Minimum Recorded Scaled Value: " + wideMin +
//   "\nMouth Wideness Maximum Recorded Scaled Value: " + wideMax + "\n\n" +
//   "\nMouth Openness Minimum Recorded Scaled Value: " + mouthAreaMin +
//   "\nMouth Openness Maximum Recorded Scaled Value: " + mouthAreaMax + "\n\n" ;
// }

export function resetMouthMinMax()
{
  minMouthAreaRaw = 1000;
  minrawMY = 1000;
  maxMouthAreaRaw = -1000;
  maxrawMY = -1000;
  mouthConfigStatus.innerText = "Mouth Tracking Minimums and Maximums are reset.\n\n";
}

export function resetMicMinMax()
{
  minMic = 1000;
  maxMic = -1000;
  curMaxMicIn.max = 0;
  micConfigStatus.innerText = "Microphone maximum is reset to 0.0.\n\n";
}

export function submitMicMaxFunc()
{
  micScaling.loud = parseFloat(micMaxInput.value);
}


export function micAutoFillSubmit()
{
  micMaxInput.value = curMaxMicIn.max.toString();
  micConfigStatus.innerText = "Microphone Max input box has been filled to current value.\n\n";
}

export function showInputValuesSection()
{
  if(inputValuesForTrackingSection.style.opacity === "0" )
  {
    inputValuesForTrackingSection.style.opacity = "1";
    configMouthTrackingButton.innerText = "Hide Mouth Tracking Configuration Controls";
  }
  else
  {
    inputValuesForTrackingSection.style.opacity = "0";
    configMouthTrackingButton.innerText = "Adjust Mouth-Tracking Response"; //test build
  }
}

// let micMaxInput : HTMLInputElement = document.getElementById("micMax") as HTMLInputElement; // initialize submit button for mouth params
// let micConfigStatus : HTMLLabelElement = document.getElementById("micConfigStatus") as HTMLLabelElement; // status for mic config
// let micAutoFill : HTMLButtonElement = document.getElementById("micAutoFill") as HTMLButtonElement; // initialize submit button for mouth params
// let submitMicMax : HTMLButtonElement = document.getElementById("submitMicMax") as HTMLButtonElement; // initialize submit button for mouth params
