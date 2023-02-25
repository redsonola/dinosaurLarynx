// HID input and a HID message
Hid hi;
HidMsg msg;

// which mouse
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open mouse 0, exit on fail
if( !hi.openMouse( device ) ) me.exit();
<<< "mouse '" + hi.name() + "' ready", "" >>>;

// infinite event loop
while( true )
{
    // wait on HidIn as event
    hi => now;
    
    // messages received
    while( hi.recv( msg ) )
    {
        // mouse motion
        if( msg.isMouseMotion() )
        {
            // get the normalized X-Y screen cursor pofaition
            <<< "mouse normalized position --",
            "x:", msg.scaledCursorX, "y:", msg.scaledCursorY >>>;
        }
    }
    
}