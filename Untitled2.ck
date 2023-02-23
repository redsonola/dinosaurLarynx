//this is redundant but I definitely know what is happening here and will stop any crazy magical thinking debug loops on this topic cold.
class diffEq extends Chugen
{
    0.5 => float v; 
    1.0 => float u;
    0.0 => float dv; 
    0.0 => float du;

    
    //the pressure up, pressure down difference
    fun float tick(float in)
    {
        v - (u*u*u) + u => du; 
        -0.0001*u => dv;
        du + u => u;
        dv + v => v;
        

    }  
}

diffEq e; 

for( 0=> int i; i< 200; i++ )
{
    e.tick(0.0);
    <<< "u: "+ e.u + " v: "+ e.v >>> ;

    
}


