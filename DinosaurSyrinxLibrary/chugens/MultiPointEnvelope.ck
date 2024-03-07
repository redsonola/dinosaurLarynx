//Courtney Brown, Jan. 2024
//create an Envelope like in Csound or Supercollider
//limit to 100 targets, etc.
public class MultiPointEnvelope extends Chugraph
{
    float startValue;
    1000 => int maxPoints;
    float targets[maxPoints]; 
    dur durations[maxPoints]; 
    float curTarget; 
    0 => int envCount; //number of targets + duration
    0 => int envIndex; 
    inlet => Envelope env; 
    "multiPointEnvelope" => string name;
    0 => int loop; //by default don't loop
    env => LPF lp => outlet; 
    
    fun void add(float target, dur duration)
    {
        target => targets[envCount]; 
        duration => durations[envCount];
        
        if(envCount < maxPoints)
            envCount++;
        else
            <<<name + " is at max capacity. Can't add more.\n">>>;
    }
    
    fun float value()
    {
        return env.value();
    }
    
    fun void reset()
    {
        init(startValue);
    }
    
    //must be run before update() but after adding points
    fun void init(float startVal)
    {
        startVal => startValue;
        startValue => env.value;
        1 => envIndex; 
        targets[0] => env.target;
        durations[0] => env.duration; 
        
    }
    
    fun float time()
    {
        return env.time(); 
    }
    
    //must be run every 1::samp or at whatever sampling rate you want. sryz.
    fun void update()
    {
        if( envIndex < envCount - 1)
        {
            if( env.value() == env.target() )
            {
                envIndex++; 
                targets[envIndex] => env.target;
                durations[envIndex] => env.duration;              
            }               
        }
        else
        {
            if( env.value() == env.target() && loop == 1 )
            {
                reset(); 
            }
        }
    }
}