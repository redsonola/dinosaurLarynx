
//ScatteringJunction
//Handles the sound signal behavior at the junction between the 
//the two bronchi and the trachea in the waveguide synthesis
//Part of syrinx modeling
//Implemented from Smyth, 2004 dissertation
//Coded by Courtney Brown
public class ScatteringJunction 
{
    Gain pJ; 
    float z0; 
    
    Gain bronchus1Z; 
    Gain bronchus2Z; 
    Gain tracheaZ; 
    Gain add;
    
    fun void updateZ0(float impedence)
    {
        impedence => z0; 
        (1.0/z0 + 1.0/z0 + 1.0/z0) => float zSum; 
        1.0/zSum => pJ.gain;
        
        1.0/z0 => bronchus1Z.gain;
        1.0/z0 => bronchus2Z.gain;
        1.0/z0 => tracheaZ.gain;
    }
    
    fun void scatter(DelayA bronch1, DelayA bronch2, DelayA trachea, 
    DelayA bronch1Delay, DelayA bronch2Delay, DelayA tracheaDelay, float impedence)
    { 
        
        bronch1 => bronchus1Z => add; 
        bronch2 => bronchus2Z => add; 
        trachea => tracheaZ => add; 
        
        //assume they have the same tube radius for now - I guess they prob. don't IRL
        1.0/z0 => bronchus1Z.gain;
        1.0/z0 => bronchus2Z.gain;
        1.0/z0 => tracheaZ.gain;
        2.0 => add.gain; 
        
        updateZ0(impedence); 
        add => pJ; 
        
        Gain bronchus1Zout;
        bronchus1Zout.op(2); 
        pJ => bronchus1Zout;
        bronch1 => bronchus1Zout => bronch1Delay;
        
        Gain bronchus2Zout;
        bronchus2Zout.op(2);
        pJ => bronchus2Zout;
        bronch2 => bronchus2Zout => bronch2Delay;
        
        Gain tracheaZout;
        tracheaZout.op(2); 
        pJ => tracheaZout;
        trachea => tracheaZout => tracheaDelay;
    }
}