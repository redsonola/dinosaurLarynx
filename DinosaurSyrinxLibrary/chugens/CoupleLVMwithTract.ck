//********************************************************************************************
//*********************** LVM TO VOCAL TRACT COUPLER **************************************************
//********************************************************************************************
//by Courtney Brown, Mar. 2024
//an attempt to couple vocal tract via waveguide synthesis, derived from Lous, et. al, 1998
//the Zacarelli model only includes the vibrating membrane, and uses dU as the sound output.
//dU is not the same as the pressure, so, I treat pressure reflections differently so that I can get them back into the model.
//this couples the pressure to the RingDoveSyrinx class. It must be connected an ltm syrinx object to work.
public class CoupleLVMwithTract extends Chugen
{
    ElemansZaccarelliDoveSyrinx lvm; //the syrinx labia
    float p1;
    
    fun float tick(float in){        
        //-- this is seconds, but I want to xlate to samples
        //does this make sense? look at parameters for airflow, too
        lvm.z0/(second/samp) * lvm.U => p1; //outgoing pressure value into the vocal tract
        
        in*2 + p1 => lvm.inputP; //put the input reflected pressure back in syrinx lvm
        return p1; //output pressure
    }
    
    fun float last()
    {
        return p1; 
    }
}
//***********************