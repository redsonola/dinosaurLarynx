
import SingleIOProcessor from "tone/build/esm/core/worklet/SingleIOProcessor.worklet";
import "./BirdTracheaFilter.worklet"
import "./tonejs_fixed/DelayLine.worklet";
import "./WallLoss.worklet";
import "./HPout.worklet";
import "./ScatteringJunction.worklet";
import "./LVMCoupler.worklet";

import { registerProcessor } from "./tonejs_fixed/WorkletLocalScope";
import * as ts from "typescript";
import { ScriptTarget } from "typescript";

//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */
class ReflectionFilter
{
    protected a1 = 1.0;
    protected b0 = 1.0;
    protected lastOut = 0.0 ; 
    protected lastV = 0.0 ; 
    protected c = 0; //speed of sound
    protected T = 0; //sample period

    //get some constants from the enclosing membrane class
    constructor(c : number, T : number)
    {
        this.c = c; 
        this.T = T; 
        this.a1 = 0;
        this.b0 = 0; 
        this.lastOut = 0; 
        this.lastV = 0;     
    }

    public tick(input : number) : number 
    {
        if(  Number.isNaN(this.lastOut) )
        {
            this.lastOut = 0;
        }
        if(  Number.isNaN(this.lastV) )
        {
            this.lastV = 0;
        }
        let vin = this.b0 * input;
        let out = vin + this.lastV - this.a1 * this.lastOut;
        this.lastOut = out; 
        this.lastV = vin; 
        
        return out; 
    }     

    public setParamsForReflectionFilter(a: number) : void
    {
   
        let ka = 1.8412; //the suggested value of 0.5 by Smyth by ka & cutoff does not seem to work with given values (eg. for smaller a given) & does not produce 
        let wT = ka*(this.c/a)*this.T;
             
        //magnitude of -1/(1 + 2s) part of oT from Smyth, eq. 4.44
        let s = ka; //this is ka, so just the coefficient to sqrt(-1), s to match Smyth paper

        //TODO: implement complex numbers >_<
        let numerator = new Complex(-1, 0);
        let denominator = new Complex(1, 2*s);
        let complexcHr_s =  numerator.divide(denominator);
        let oT = Math.sqrt( complexcHr_s.re*complexcHr_s.re + complexcHr_s.im*complexcHr_s.im ); //magnitude of Hr(s)
        
        let alpha = ( 1 + Math.cos(wT) - 2*oT*oT*Math.cos(wT) ) / ( 1 + Math.cos(wT) - 2*oT*oT ); //to determine a1 
        this.a1 = -alpha + Math.sqrt( alpha*alpha - 1 );
        this.b0 = (1 + this.a1 ) / 2;     
        
        //for the highpass output, from Smyth, again -- HPFilter class
        // a1 => hpOut.a1; 
        // b0 => hpOut.b0; 
        
        //console.log("alpha: " alpha + " oT: " + oT + " wT: " + wT);
        //console.log("a: "+ a+ " a1: "+this.a1 + "   b0: "+this.b0);
    }
   
}
//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */
class HPFilter
{
    protected a1 : number = 1; 
    protected b0 : number = 1; 
    protected lastOut : number = 0; 
    protected lastV : number = 0; 

    constructor(a1:number, b0:number)
    {
        this.a1 = a1; 
        this.b0 = b0;
        this.lastOut = 0; 
        this.lastV = 0; 

    }
    
    public tick(input : number) : number
    {
        if(  Number.isNaN(this.lastOut) )
        {
            this.lastOut = 0;
        }
        if(  Number.isNaN(this.lastV) )
        {
            this.lastV = 0;
        }

        let vin = input - this.b0*input;
        let output = vin + (this.a1-this.b0)*this.lastV - this.a1*this.lastOut;
        this.lastOut = output; 
        this.lastV = vin; 
        return output; 
    }     
}
//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */
class LVMCoupler
{
    protected p1 : number ; 
    protected lvm : any;

    constructor(l : any)
    {
        this.lvm = l; 
        this.p1 = 0;
    }
    
    public tick(input : number) : number
    {
        //-- this is seconds, but I want to xlate to samples
        //does this make sense? look at parameters for airflow, too
        
        //prevent blowups
        if (input > 3.0)
        {
            input = 0;
        }
        
        this.p1 = this.lvm.z0/this.lvm.SRATE * this.lvm.U; //outgoing pressure value into the vocal tract
        
        this.lvm.inputP = input*2 + this.p1;
        return this.p1; //output pressure  
    }
    
    public last()
    {
        return this.p1; 
    }
}
//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */

class ScatteringJunction 
{
    protected z0 : number;
    protected tubeZ : number;   
    protected zSum : number;    

    constructor(impedence : number)
    {
        this.z0 = 0;
        this.tubeZ = 0;
        this.zSum = 0; 
        this.updateZ0(impedence);
    }
    
    public updateZ0(impedence : number) : void
    {
        this.z0 = impedence; 
        this.zSum = (1.0/this.z0 + 1.0/this.z0 + 1.0/this.z0);         
        this.tubeZ = 1.0/this.z0;
    }
    
    public scatter(bronch1 : number, bronch2 : number, trachea : number) : any
    { 
        let bronch1Out : number = 0; 
        let bronch2Out : number = 0; 
        let tracheaOut : number = 0; 

        let add = bronch1*this.tubeZ + bronch2*this.tubeZ +  trachea*this.tubeZ;
        add *= 2; 

        //assume they have the same tube radius for now
        let pJ = add / this.zSum;
    
        return {b1: pJ-bronch1, b2: pJ-bronch2, trach: pJ-trachea};
    }
}
//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */
class WallLossAttenuation //tuned to dino
{
    protected L = 116.0; //in cm --divided by 2 since it is taken at the end of each delay, instead of at the end of the waveguide
    private c = 34740; // in m/s
    protected freq = this.c/(2*this.L);
    protected w  = this.wFromFreq(this.freq);   
    //150.0*2.0*pi => float w;  
    
    protected a = 0.35; //  1/2 diameter of trachea, in m - NOTE this is from SyrinxMembrane -- 
                     //TODO:  to factor out the constants that are used across scopes: a, L, c, etc
    protected propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff(); //theta in Fletcher1988 p466
    protected wallLossCoeff = this.calcWallLossCoeff(); //beta in Fletcher 
    
    constructor(L: number, a: number)
    {
        this.update(L, a);
    }
    
    //update given new length & width
    public update(L: number, a: number) : void
    {
        this.L = L; 
        this.a = a; 
        this.freq = this.c/(2*L) ;
        this.w = this.wFromFreq(this.freq);
        this.propogationAttenuationCoeff = this.calcPropogationAttenuationCoeff();
        this.wallLossCoeff = this.calcWallLossCoeff();
    } 
    
    protected calcWallLossCoeff() : number
    {
        //return 1.0 - (1.2*propogationAttenuationCoeff*L);
        return 1.0 - (2.0*this.propogationAttenuationCoeff*this.L);
    }
    
    protected calcPropogationAttenuationCoeff() : number
    {
        return (5*Math.pow(10, -5)*Math.sqrt(this.w)) / this.a; //changed the constant for more loss, was 2.0, intuitive tuning, TODO: implement cascade filters, or look at how to adjust constant
    }
    
    public wFromFreq(frq : number) : number
    {
        return frq*Math.PI*2; 
    }
    
    protected setFreq( f : number ) : void 
    {
        this.wFromFreq(f); 
    }
    
    //the two different bronchi as they connect in1 & in2
    public getWallLossCoeff() : number
    {
        return this.wallLossCoeff;
    } 

    public tick(input : number)
    {
        return input*this.wallLossCoeff; 
    }
}
//******************************************************************************************************** */
//******************************************************************************************************** */
//******************************************************************************************************** */

class SyrinxMembraneGenerator extends SingleIOProcessor {
    
    protected lastSample : number = 0; //last sample from the output
    protected FletcherSmyth : number = 0;
    protected ElemansZacharelli : number = 1;
    protected whichVocalModel : number = this.ElemansZacharelli; //default
    protected lastSample2 : number = 0; //last sample from the output
    protected lastTracheaSample : number = 0; //last sample from the output
    protected lastPressureSamp : number = 0; //last sample from the output
    protected delayTimeBronchi : number = 0; //delay of each of the bronchi sides
    protected delayTime : number = 0; //the trachea delay time
    protected channelCount : number;
    protected bronch1Delay1 : DelayLine;
    protected bronch1Delay2 : DelayLine;
    protected bronch2Delay1 : DelayLine;
    protected bronch2Delay2 : DelayLine;
    protected tracheaDelay1 : DelayLine;
    protected tracheaDelay2 : DelayLine;
    protected bronch1Delay1Pressure : DelayLine;
    protected bronch1Delay2Pressure : DelayLine;
    protected membrane : any;
    protected membrane2 : any;

    protected bronch1Filter : ReflectionFilter;
    protected bronch2Filter : ReflectionFilter;
    protected tracheaFilter : ReflectionFilter;

    protected tracheaFilterPressure : ReflectionFilter;
    protected wallLoss : WallLossAttenuation;
    protected hpOut : HPFilter;
    protected scatteringJunction : ScatteringJunction;
    protected lvmCoupler : any = null; //for ElemansZacharelli

    protected max : number; 
    protected generateFunction : any;
    protected count : number;
    protected membraneCount : number;   

    constructor(options : any) {
        super(options);

        this.FletcherSmyth = 0;
        this.ElemansZacharelli = 1;
        this.whichVocalModel = this.ElemansZacharelli; //default

        this.createMembrane(); //create the membrane

        this.lastSample = 0;
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 
        this.lastPressureSamp = 0; //for ElemansZacharelli -- hmm... not sure if I like how I'm handling this

        this.delayTimeBronchi = 0; //delay of each of the bronchi sides
        this.delayTime = 0; //the trachea delay time

        this.channelCount = options.channelCount;


        //one for each way
        this.bronch1Delay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch1Delay2 = new DelayLine(this.sampleRate, options.channelCount || 2);

        this.bronch2Delay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch2Delay2 = new DelayLine(this.sampleRate, options.channelCount || 2);

        this.tracheaDelay1 = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.tracheaDelay2 = new DelayLine(this.sampleRate, options.channelCount || 2);

        this.bronch1Delay1Pressure = new DelayLine(this.sampleRate, options.channelCount || 2);
        this.bronch1Delay2Pressure = new DelayLine(this.sampleRate, options.channelCount || 2);
        
        //hadrosaur values
        this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilterPressure = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilterPressure.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTrachealSyrinx;
        this.membraneCount = 1; 
        this.setDelayTime( this.getPeriod() );

        //for smyth fletcher -- TODO-- change with the syrinx model
        //this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.

        this.max = 1; //for elemans zacharelli


        this.count = 0; //for outputting values at a lower rate

    }

    protected setSyrinxModel(which : number) : void
    {
        if( which != this.whichVocalModel )
        {
            this.whichVocalModel = which; 
            this.initFunc(true);
        }
    }

    protected createMembrane() : void
    {
        if( this.whichVocalModel == this.FletcherSmyth || this.whichVocalModel != this.ElemansZacharelli ) //if which is garbage, set to default
        {
            this.membrane = new SyrinxMembrane();
            this.membrane2 = new SyrinxMembrane();
        }
        else
        {
            this.membrane = new RingDoveSyrinx();
            this.membrane2 = new RingDoveSyrinx();
            this.lvmCoupler = new LVMCoupler(this.membrane); //for ElemansZacharelli

        }
    }

    protected initFunc(createNewMembrane : boolean = true) : void
    {
        if( createNewMembrane )
        {
            this.createMembrane(this.whichVocalModel);
        }

        this.lastSample = 0;
        this.lastPressureSamp = 0;       
        this.lastSample2 = 0; 
        this.lastTracheaSample = 0; 

        this.delayTimeBronchi = 0; //delay of each of the bronchi sides
        this.delayTime = 0; //the trachea delay time

        //one for each way
        this.bronch1Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch1Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.bronch1Delay1Pressure = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch1Delay2Pressure = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.bronch2Delay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.bronch2Delay2 = new DelayLine(this.sampleRate, this.channelCount || 2);

        this.tracheaDelay1 = new DelayLine(this.sampleRate, this.channelCount || 2);
        this.tracheaDelay2 = new DelayLine(this.sampleRate, this.channelCount || 2);
        
        //hadrosaur values
        if( this.whichVocalModel == this.FletcherSmyth )
            this.hadrosaurInit();

        //the reflection filters for each tube: bronchi & trachea
        this.bronch1Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch1Filter.setParamsForReflectionFilter(this.membrane.a);

        this.bronch2Filter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.bronch2Filter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilter = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilter.setParamsForReflectionFilter(this.membrane.a);

        this.tracheaFilterPressure = new ReflectionFilter(this.membrane.c, this.membrane.T); 
        this.tracheaFilterPressure.setParamsForReflectionFilter(this.membrane.a);

        //we'll need separate wall losses as well...
        this.wallLoss = new WallLossAttenuation(this.membrane.L, this.membrane.a);

        this.hpOut = new HPFilter(this.tracheaFilter.a1, this.tracheaFilter.b0);
        this.scatteringJunction = new ScatteringJunction(this.membrane.z0);

        //the delay of comb filter for the waveguide
        //which syrinx
        this.generateFunction = this.generateTracheobronchial;
        this.membraneCount = 2; 
        this.setDelayTime( this.getPeriod() );

        this.max = 51520; //for some simple scaling into more audio-like numbers -- output from this should still be passed on to limiter
                          //TODO: perhaps implementing something custom for this, we'll see.


        this.count = 0; //for outputting values at a lower rate
    }

    //set delay time
    protected setDelayTime(period : number)
    {
        this.delayTime = period; 

        //values from Smyth 2002, in mm
        //large bird - bronchus to trachea - 30/35.6 -- taking the large bird radius (still a small bird)
        //medium bird - bronchus to trachea - 14/23
        //small bird - bronchus to trachea - 5/17.1


        //ok just testing here
        if(this.membraneCount >= 2)
        {
            //let's say the MTM bronchi to the trachea length is 1/15 of the trachea 
            //I got this by looking at diagrams
            this.delayTimeBronchi = period*(30/35.6);  
        }

    }

    //period of the comb filter for the waveguide
    protected getPeriod() : number
    {
        let LFreq = this.membrane.c/(2*this.membrane.L);
        let period = 0.5 / LFreq;
        return period; //in seconds 
    }

    protected hadrosaurInit() : void
    {
        //in cm
        this.membrane.a = 4.5; 
        this.membrane.h = 4.5; 
        this.membrane.L = 116; //dummy
        this.membrane.d = 5; 

        //in various
        this.membrane.modT = 10000.0; 
        this.membrane.modPG = 80;
   
        this.membrane.initTension(); 
        this.membrane.initZ0;

        //repeat, maybe I should arrayify...
        this.membrane2.a = 4.5; 
        this.membrane2.h = 4.5; 
        this.membrane2.L = 116; //dummy
        this.membrane2.d = 5; 

        //in various
        this.membrane2.modT = 10000.0; 
        this.membrane2.modPG = 80;
   
        this.membrane2.initTension(); 
        this.membrane2.initZ0;
    }

    static get parameterDescriptors() {
        return [{
            name: "pG",
            defaultValue: 0,
            minValue: 0,
            maxValue: 2500000,
            automationRate: "k-rate"
        },
        {
            name: "tension",
            defaultValue: 2000,
            minValue: 0,
            maxValue: 168397230,
            automationRate: "k-rate"
        }, 
        {
            name: "Ps",
            defaultValue: 0,
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        },
        {
            name: "ptl",
            defaultValue: 0,
            minValue: 0,
            maxValue: 40,
            automationRate: "k-rate"
        }, 
        {
            name: "pt", //currently not implemented
            defaultValue: 0,
            minValue: -2,
            maxValue: 2,
            automationRate: "k-rate"
        }, 
        {
            name: "inputMusclePressure", //currently not implemented
            defaultValue: 0,
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        }, 
        {
            name: "syrinxModel", //currently not implemented
            defaultValue: 1, //0 for FletcherSmyth, 1 for ElemansZacharelli, default is Elemans for now
            minValue: 0,
            maxValue: 1,
            automationRate: "k-rate"
        }, 
        {
            name: "membraneCount",
            defaultValue: 1,
            minValue: 1,
            maxValue: 2,
            automationRate: "k-rate"
        } 
        ];
    } 

    generate(input:any, channel:any, parameters:any) {
        return this.generateFunction(input, channel, parameters);  //default is Tracheobronchial for now
    }

    //single wave guide -- take in a syrinx membrane & resonate through a trachea
    waveguideSingleMembrane( inSample: number, delay1: any, delay2: any, tracheaFilter:any, lastSamp:number, channel: any, parameters: any ) : number
    {
        //********1st delayLine => tracheaFilter => flip => last sample  *********
        let curOut = this.delayLineGenerate(inSample+lastSamp, channel, parameters, delay1, this.delayTime);
        lastSamp = tracheaFilter.tick(curOut); //low-pass filter
        lastSamp = lastSamp * -1; //flip

        //********2nd delayLine, going back *********
        lastSamp = this.delayLineGenerate(lastSamp, channel, parameters, delay2, this.delayTime);
        let fout = this.wallLoss.tick(lastSamp); 

        return fout;
    }

    //NOTE: Web Audio API does NOT allow cycles except when there is a delay, which introduces at least 1 buffer of audio delay (128 samples) 
    //which is not fine enough granularity for the waveguides. So all processing for the syrinx is here.
    //I will refactor this later.
    //my GOD! what a #$%^&*&^%^&*ing pain.
    generateTrachealSyrinx(input:any, channel:any, parameters:any) {

        if(  Number.isNaN(this.lastSample) )
        {
            this.lastSample = 0;
        }
         
        if(  Number.isNaN(this.lastSample2) )
        {
            this.lastSample2 = 0;
        }

        if(  Number.isNaN(this.lastPressureSamp) )
        {
             this.lastPressureSamp = 0;
        }

        if(  Number.isNaN(this.lastTracheaSample) )
        {
            this.lastTracheaSample = 0;
        }

        //*****implementing this chuck code.....

        //from membrane to trachea and part way back
        //SyrinxMembrane mem => DelayA delay => lp => Flip flip => DelayA delay2 => WallLossAttenuation wa; //reflection from trachea end back to bronchus beginning
        
        //the feedback from trachea reflection
        //Gain p1; 
        //wa => p1; 
        //mem => p1; 
        ////p1 => DelayA oz =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 =>  mem; //the reflection also is considered in the pressure output of the syrinx
        //p1 => delay; 
        //************

        //**** syrinx membrane ******
        if ( this.whichVocalModel == this.FletcherSmyth )
        {
            this.membrane.changePG(parameters.pG);
            this.membrane.changeTension(parameters.tension);
        }
        else if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            //note: using the built-in 0-1 mapping membrane synthesis side for now.
            this.membrane.updateInputPressure(parameters.Ps);
            this.membrane.updateInputMusclePressure(parameters.inputMusclePressure);
        }

        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 

        //travel through the trachea tubes
        let fout = this.waveguideSingleMembrane( pOut, this.bronch1Delay1, this.bronch1Delay2, this.tracheaFilter, this.lastSample, channel, parameters );
        this.lastSample = fout;
        //******** Add delay lines ==> High Pass Filter => out  *********
        fout = fout + this.lastSample;
        fout = this.hpOut.tick(fout);

        let reflectedPressure = 0;
        if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            reflectedPressure = this.waveguideSingleMembrane( this.lvmCoupler.last()+this.lastPressureSamp, this.bronch1Delay1Pressure, this.bronch1Delay2Pressure, this.tracheaFilterPressure, this.lastPressureSamp, channel, parameters );
            this.lvmCoupler.tick(reflectedPressure);
            this.lastPressureSamp = reflectedPressure;
        }
        //console.log("reflectedPressure: " + reflectedPressure);

        //****** simple scaling into more audio-like values, sigh  *********
        //fout = fout/this.max;  

        //test to see if I need a limiter
        // this.count++;
        // if( this.max < fout )
        // {
        //     console.log("max: "+ this.max);
        // }
        // this.max = Math.max(this.max, fout); 

        // if(this.count >50)
        // {
        //     this.count = 0;
        // }    

    
        if (Math.abs(fout) > 1.0)
        {
            this.max = Math.max(this.max, fout);
            fout = fout/this.max;
        }
    
        //****** output w/high pass *********      
        return fout;
    }

    //2 membranes, as in passerines
    generateTracheobronchial(input:any, channel:any, parameters:any) {

        //**** syrinx membrane ******
        //this.setSyrinxModel(parameters.syrinxModel);
        if ( this.whichVocalModel == this.FletcherSmyth )
        {
            this.membrane.changePG(parameters.pG);
            this.membrane.changeTension(parameters.tension);

            this.membrane2.changePG(parameters.pG);
            this.membrane2.changeTension(parameters.tension);
        }
        else if ( this.whichVocalModel == this.ElemansZacharelli )
        {
            //note: using the built-in 0-1 mapping membrane synthesis side for now.
            this.membrane.updateInputPressure(parameters.Ps);
            this.membrane.updateInputMusclePressure(parameters.inputMusclePressure);

            this.membrane2.updateInputPressure(parameters.Ps);
            this.membrane2.updateInputMusclePressure(parameters.inputMusclePressure);
        }       

        // this.count++;
        // if(this.count >50)
        // {
        //     console.log(this.membrane.pG + ", " + parameters.tension);
        //     this.count = 0;
        // }

        //******** Sound is generated and travels up each bronchi *********
        const pOut = this.membrane.tick(this.lastSample); //the syrinx membrane  //Math.random() * 2 - 1; 
        let curOut = this.delayLineGenerate(pOut+this.lastSample, channel, parameters, this.bronch1Delay1, this.delayTimeBronchi);
        this.lastSample = this.bronch1Filter.tick(curOut); //low-pass filter
        this.lastSample = this.lastSample * -1; //flip

        const pOut2 = this.membrane2.tick(this.lastSample2); //the syrinx membrane  //Math.random() * 2 - 1; 
        let curOut2 = this.delayLineGenerate(pOut2+this.lastSample2, channel, parameters, this.bronch2Delay1, this.delayTimeBronchi);
        this.lastSample2 = this.bronch2Filter.tick(curOut2); //low-pass filter
        this.lastSample2 = this.lastSample2 * -1; //flip 

        //******** Sound encounters Junction *********
        let scatterOut = this.scatteringJunction.scatter(curOut, curOut2, this.lastTracheaSample); 

        //******** Sound travels through trachea *********
        let trachOut = this.delayLineGenerate(scatterOut.trach + this.lastTracheaSample, channel, parameters, this.tracheaDelay1, this.delayTime);
        this.lastTracheaSample = this.tracheaFilter.tick(trachOut); //low-pass filter
        this.lastTracheaSample = this.lastTracheaSample * -1; //flip 

        //******** Sound is reflected from bronchi & trachea *********
        this.lastSample = this.delayLineGenerate(scatterOut.b1, channel, parameters, this.bronch1Delay2, this.delayTimeBronchi);
        this.lastSample = this.wallLoss.tick(this.lastSample); 

        this.lastSample2 = this.delayLineGenerate(scatterOut.b2, channel, parameters, this.bronch2Delay2, this.delayTimeBronchi);
        this.lastSample2 = this.wallLoss.tick(this.lastSample2); 

        this.lastTracheaSample = this.delayLineGenerate(this.lastTracheaSample, channel, parameters, this.tracheaDelay2, this.delayTime);
        //this.lastTracheaSample = this.wallLoss.tick(this.lastTracheaSample); 

        //******** Add delay lines ==> High Pass Filter => out  *********
        trachOut = trachOut + this.lastTracheaSample;
        let fout = this.hpOut.tick(trachOut);
        
        //****** simple scaling into more audio-like values, sigh  *********
        if( this.whichVocalModel == this.FletcherSmyth )
        {
            fout = fout/(this.max*2);   
        } 
        else
        {
            if (Math.abs(fout) > 1.0)
            {
                this.max = Math.max(this.max, fout);
                fout = fout/this.max;
                console.log("max: " + this.max);
            }
        }
        
        if( Number.isNaN(fout) )
        { 
            console.log(" NaN detected.... relaunching ");
            this.initFunc();
            fout = this.lastSample;
        }

        
        return fout;
    }


    //this is the delayLine generate -- note: I will probably have to have multiple delay lines
    //this function altered slightly from tonejs FeedbackCombFilter
    protected delayLineGenerate(input, channel, parameters, delayLine, delayTime) : number {
        const delayedSample = delayLine.get(channel, delayTime * this.sampleRate);
        delayLine.push(channel, input);
        return delayedSample;
    }
}