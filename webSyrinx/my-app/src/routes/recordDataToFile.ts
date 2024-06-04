
//modified from https://www.tutorialspoint.com/how-to-create-and-save-text-file-in-javascript

export class DataFileCSV
{   
    saveddata: string = "";
    header: string = "";
    isRecording: boolean = false;
    filename: string = "";

    constructor(filename: string, header: string)
    {
        this.filename = filename;
        this.header = header;
        this.clearFile();
    }

    //var mouthSavedData ="";
    public downloadFile() : void
    {
        const link = document.createElement("a");
        const file = new Blob([this.saveddata], { type: 'text/plain' });
        link.href = URL.createObjectURL(file);
        link.download = this.filename;
        link.click();
        URL.revokeObjectURL(link.href);
    }   

    public clearFile() : void
    {
        console.log("cleared");
        this.saveddata = this.header + "\n"; //start with the headers
    }

    public toggleRecording() //clears file on start.....
    {
        this.isRecording = !this.isRecording;

        if( this.isRecording )
        {
            this.clearFile();
        }

        console.log("recording: " + this.isRecording);
    }

    public addData(data: any[]) : void
    {
        if (this.isRecording)
        {
            for (let i = 0; i < data.length; i++)
            {
                this.saveddata += data[i] + ",";
            }
            this.saveddata += "\n";
        }
    }
}
