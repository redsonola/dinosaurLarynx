//holds mouth measures
import { DataFileCSV } from '../recordDataToFile'; //things I want to import

const mouthDataFileName = "mouthData.csv";
const mouthDataHeader = "Wideness Min, Wideness Max, Open Min, Open Max";
export const mouthDataFile : DataFileCSV = new DataFileCSV(mouthDataFileName, mouthDataHeader);

//updated with better values, depth normalization
export var wideMin = 10;   //0.14866; //0.07;
export var wideMax = 250; //0.34627; //0.12;
export var mouthAreaMin = 0.05; //0.000291; //0.0; 
export var mouthAreaMax = 75; //0.021153; //0.005480977000770437

//camera position:
//9cm back from mouthpiece, centered horizontally
//camera 0.75inch from the back of the stand, slight forward tilt

export var setMouthWideMin = (value: number) => {
    wideMin = value;
}

export var setMouthWideMax = (value: number) => {    
    wideMax = value;
}

export var setMouthAreaMin = (value: number) => {
    mouthAreaMin = value;
}

export var setMouthAreaMax = (value: number) => {
    mouthAreaMax = value;
}   