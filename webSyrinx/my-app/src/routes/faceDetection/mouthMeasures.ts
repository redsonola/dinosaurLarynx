//holds mouth measures
import { DataFileCSV } from '../recordDataToFile'; //things I want to import

const mouthDataFileName = "mouthData.csv";
const mouthDataHeader = "Wideness Min, Wideness Max, Open Min, Open Max";
export const mouthDataFile : DataFileCSV = new DataFileCSV(mouthDataFileName, mouthDataHeader);

export var wideMin = 0.07;
export var wideMax = 0.12;
export var mouthAreaMin = 0.0; 
export var mouthAreaMax = 0.005480977000770437

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