//okay, this is just to test -- sanity debug check -- make sure -- obviously I can't keep this as a chugen, but probably
//in end result will not be using chugens at all.
class BirdTracheaFilter extends Chugen
{
    1.0 => float a1;
    1.0 => float b0;
    0.0 => float lastOut; 
    0.0 => float lastV; 
    
    fun float tick(float in)
    {
        b0*in => float vin;
        vin + lastV - a1*lastOut => float out;
        out => lastOut; 
        vin => lastV; 
        return out; 
    }     
}

fun void oscilloscope(UGen @ in){ oscilloscope(in, 80, 24, 25::ms, -1.0, 1.0, 20::ms, 200::ms); }
//Waits for a positive zero crossing and prints the waveform
fun void oscilloscope(UGen @ in,int x_resolution, int y_resolution, dur x_max, float y_min, float y_max , dur min_duration, dur max_duration){
    x_max/(x_resolution$float) => dur x_grid_size;
    (y_max-y_min)/(y_resolution$float) => float y_grid_size;
    float amplitude[x_resolution];
    float deriv;
    int index;
    int capturing;
    int mark[x_resolution];
    in.last() => float prev;
    string screen;
    while(true){
        true => capturing;
        0 => index;
        while( capturing ){
            x_grid_size => now;
            if(index < amplitude.cap() ) in.last() => amplitude[index];
            index++;
            if( (prev < 0.0 && in.last() > 0.0 && index::x_grid_size > min_duration) || index::x_grid_size > max_duration ) false => capturing;
            in.last() => prev;
        }
        //for(index => int i; i < amplitude.cap(); i++) 0.0 => amplitude[i]; //Clear the tail from garbage
        "" => screen;
        for(0 => int y; y < y_resolution; y++){
            for(0 => int x; x < x_resolution && x < index; x++){
                if( Math.round((amplitude[x]-y_min)/y_grid_size) == y_resolution - y ){
                    amplitude[ (x+1)%amplitude.cap() ] - amplitude[x] => deriv;
                    //if( Std.fabs(deriv) > y_grid_size*2.0 ) "|" +=> screen;
                    //if( deriv < -y_grid_size ) "\\" +=> screen;
                    if( deriv < -y_grid_size ){ true => mark[x]; " " +=> screen; } //Drop down one row
                    else if( deriv > y_grid_size ) "/" +=> screen;
                    else "_" +=> screen;
                }
                else if( mark[x] ){ "\\" +=> screen; false => mark[x]; }
                else " " +=> screen;
            }
            "\n" +=> screen;
        }
        <<<screen,"">>>;
    }
    
}

//Let's try it:
Impulse i => BirdTracheaFilter c => blackhole;



oscilloscope(c);
1::second => now;